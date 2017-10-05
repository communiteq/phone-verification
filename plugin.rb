# name: phone-verification
# about: Phone verification
# version: 0.2
# author: Muhlis Budi Cahyono (muhlisbc@gmail.com)
# url: https://github.com/muhlisbc

#load File.expand_path('../lib/phone_verification/engine.rb', __FILE__)

enabled_site_setting :phone_verification_enabled

gem "phonelib", "0.6.15", require: true
gem "libxml-ruby", "3.0.0", require: false
gem "twilio-ruby", "5.2.3", require: true

after_initialize {

  require_dependency File.expand_path("../jobs/send_sms_verification.rb", __FILE__)
  require_dependency File.expand_path("../jobs/set_user_needs_verify_phone.rb", __FILE__)

  module ::PhoneVerificationHelper
    def self.admin_serialize_data(object)
      object.custom_fields ||= {}
      {
        needs_verify_phone: object.custom_fields["needs_verify_phone"],
        phone_numbers: object.custom_fields["phone_numbers"],
        hide: (object.admin || PhoneVerificationHelper.invited_by_admin?(object))
      }
    end

    def self.send_sms(to, body)
      client = Twilio::REST::Client.new(SiteSetting.phone_verification_twilio_account_sid, SiteSetting.phone_verification_twilio_auth_token)
      client.api.account.messages.create(from: SiteSetting.phone_verification_twilio_sending_phone_numbers, to: to, body: body)
    end

    def self.sms_provider_is_set?
      SiteSetting.phone_verification_twilio_account_sid.present? &&
      SiteSetting.phone_verification_twilio_auth_token.present? &&
      SiteSetting.phone_verification_twilio_sending_phone_numbers.present?
    end

    def self.send_sms_verification?(user)
      self.is_needs_verify_phone(user)
    end

    def self.needs_verify_phone?(user)
      SiteSetting.phone_verification_enabled && !self.invited_by_admin?(user)
    end

    def self.invited_by_admin?(user)
      user.invited_by && user.invited_by.admin
    end

    def self.is_needs_verify_phone(user)
      SiteSetting.phone_verification_enabled &&
      self.sms_provider_is_set? &&
      !user.blocked &&
      !user.suspended? &&
      #user.email_confirmed? &&
      !self.invited_by_admin?(user) &&
      user.custom_fields["needs_verify_phone"] == "true"
    end
  end

  module ::PhoneVerification
    class Engine < ::Rails::Engine
      engine_name "phone_verification"
      isolate_namespace PhoneVerification
    end
  end

  require_dependency "application_controller"
  class PhoneVerification::PhoneController < ::ApplicationController

    before_action :check_is_needs_to_verify_phone, only: [:index]

    before_action :mmn_check_current_user, only: [:set_phone_numbers, :send_code, :verify_code, :get_state]
    before_action :mmn_set_user_for_admin, only: [:admin_set_phone_numbers, :admin_send_code, :admin_del_phone_numbers, :admin_force_verification, :admin_set_as_verified]

    def index
      render html: "", layout: true
    end

    def set_phone_numbers
      status, data = set_phone_numbers_for_user
      render json: {status: status, data: data}
    end

    def send_code
      status, data = send_code_for_user
      render json: {status: status, data: data}
    end

    def verify_code
      verification_code = params["verification_code"]
      status, data =
        if !verification_code.blank? && verification_code == current_user.custom_fields["verification_code"]
          if (Time.now.to_i - current_user.custom_fields["last_verification_code_sent_at"].to_i) > SiteSetting.phone_verification_code_valid_for.to_i.hour.to_i
            ["error", c_t("verification_code_expired")]            
          else
            current_user.custom_fields["needs_verify_phone"] = "verified"
            current_user.save!
            ["success", ""]
          end
        else
          ["error", c_t("invalid_verification_code")]
        end

      render json: {status: status, data: data}
    end

    def get_state
      render json: response_data
    end

    def admin_set_phone_numbers
      status, data = set_phone_numbers_for_user
      render json: {status: status, data: data}
    end

    def admin_send_code
      status, data = send_code_for_user
      render json: {status: status, data: data}
    end

    def admin_del_phone_numbers
      edit_count = @user.custom_fields["edit_phone_numbers_count"].to_i
      new_edit_count = ((edit_count - 1) < 0) ? 0 : (edit_count - 1)
      admin_update_user_custom_fields("phone_numbers" => nil, "edit_phone_numbers_count" => new_edit_count)
    end

    def admin_force_verification
      admin_update_user_custom_fields("needs_verify_phone" => "true", "edit_phone_numbers_count" => 0)
    end

    def admin_set_as_verified
      admin_update_user_custom_fields("needs_verify_phone" => "verified")
    end

    private

    def check_is_needs_to_verify_phone
      expires_now
      if (!current_user || !PhoneVerificationHelper.is_needs_verify_phone(current_user))
        redirect_to main_app.root_path
      end
    end

    def mmn_check_current_user
      if current_user && PhoneVerificationHelper.is_needs_verify_phone(current_user)
        @user = current_user
      else
        ren_je(c_t("not_allowed"))
      end
    end

    def mmn_set_user_for_admin
      if current_user && current_user.admin && SiteSetting.phone_verification_enabled
        if sms_provider_is_set
          @user = User.where(id: params["id"]).first

          # if user doesn't exists
          if !@user
            ren_je(c_t("user_not_found"))
          end
        else
          ren_je(c_t("sms_provider_not_set"))
        end
      else
        ren_je(c_t("not_allowed"))
      end
    end

    def send_verification_code
      verification_code = rand(100_000...1_000_000)

      @user.custom_fields["needs_verify_phone"] = "true"
      @user.custom_fields["verification_code"]  = verification_code

      if !current_user.admin
        @user.custom_fields["verification_code_sent_count"] = (verification_code_sent_today + 1)
      end

      @user.custom_fields["last_verification_code_sent_at"] = Time.now.to_i

      @user.save!

      Jobs.enqueue(:send_sms_verification, user_id: @user.id)
    end

    def verification_code_sent_today
      (@user.custom_fields["last_verification_code_sent_at"].to_i < Time.now.beginning_of_day.to_i) ? 0 : @user.custom_fields["verification_code_sent_count"].to_i
    end

    def send_code_left
      SiteSetting.phone_verification_max_sms_verification_code_sent_a_day.to_i - verification_code_sent_today
    end

    def edit_phone_numbers_left
      SiteSetting.phone_verification_max_edit_phone_numbers_allowed.to_i - @user.custom_fields["edit_phone_numbers_count"].to_i
    end

    def response_data
      {
        phone_numbers:                user_phone_numbers,
        edit_phone_numbers_left:      edit_phone_numbers_left,
        send_code_left:               send_code_left,
        template:                     tpl_to_render,
        verification_code_valid_for:  SiteSetting.phone_verification_code_valid_for,
        sms_provider_is_set:          sms_provider_is_set,
        needs_verify_phone:           PhoneVerificationHelper.is_needs_verify_phone(@user)
      }      
    end

    def tpl_to_render
      user_phone_numbers.blank? ? "enter_phone" : "enter_code"
    end

    def user_phone_numbers
      @user.custom_fields["phone_numbers"]
    end

    def set_phone_numbers_for_user
      phone_numbers = params["phone_numbers"]
      status        = "error"
      data          =
        if phone_numbers.present?
          if (current_user.admin || edit_phone_numbers_left > 0)
            parsed_phone_numbers = Phonelib.parse(phone_numbers)

            if parsed_phone_numbers.valid?
              # noop if phone numbers doesn't change
              if parsed_phone_numbers.e164 == user_phone_numbers
                status = "success"
                response_data
              else
                # ensure the phone numbers is unique
                if UserCustomField.where(name: "phone_numbers", value: parsed_phone_numbers.e164).first.blank?

                  @user.custom_fields["phone_numbers"] = parsed_phone_numbers.e164

                  resp_data =
                    # don't send SMS verification code and increment the counter if triggered by admin
                    if current_user.admin
                      @user.save!
                      PhoneVerificationHelper.admin_serialize_data(@user)
                    else
                      @user.custom_fields["edit_phone_numbers_count"] = (@user.custom_fields["edit_phone_numbers_count"].to_i + 1)
                      send_verification_code
                      response_data
                    end

                  status = "success"
                  resp_data
                else
                  c_t("phone_numbers_exists")
                end
              end
            else
              c_t("invalid_phone_numbers")
            end
          else
            c_t("max_edit_phone_numbers_reached")
          end
        else
          c_t("invalid_phone_numbers")
        end

      [status, data]
    end

    def send_code_for_user
      status  = "error"
      data    =
        if (current_user.admin || send_code_left > 0)
          send_verification_code
          status = "success"
          response_data
        else
          c_t("max_verification_code_sent_reached")
        end

      [status, data]
    end

    def sms_provider_is_set
      PhoneVerificationHelper.sms_provider_is_set?
    end

    def ren_je(data)
      render(json: {status: "error", data: data})
    end

    def admin_update_user_custom_fields(values)
      values.each do |k, v|
        @user.custom_fields[k] = v
      end
      @user.save!
      render(json: {status: "success", data: PhoneVerificationHelper.admin_serialize_data(@user)})
    end

    def c_t(k)
      I18n.t("phone_verification.#{k}")
    end

  end

  Discourse::Application.routes.append do
    mount ::PhoneVerification::Engine, at: "/phone-verification"
  end


  PhoneVerification::Engine.routes.draw do
    root to: "phone#index"

    get "/state"                    => "phone#get_state"
    get "/send_code"                => "phone#send_code"
    post "/verify_code"             => "phone#verify_code"
    post "/set_phone_numbers"       => "phone#set_phone_numbers"

    post "/admin_set_phone_numbers" => "phone#admin_set_phone_numbers"
    get "/admin_send_code"          => "phone#admin_send_code"
    get "/admin_del_phone_numbers"  => "phone#admin_del_phone_numbers"
    get "/admin_force_verification" => "phone#admin_force_verification"
    get "/admin_set_as_verified"    => "phone#admin_set_as_verified"
  end

  require_dependency 'current_user_serializer'
  class ::CurrentUserSerializer
    attributes :needs_verify_phone

    def needs_verify_phone
      PhoneVerificationHelper.is_needs_verify_phone(object)
    end

  end

  require_dependency 'admin_detailed_user_serializer'
  class ::AdminDetailedUserSerializer
    attributes :phone_verification

    def phone_verification
      PhoneVerificationHelper.admin_serialize_data(object)
    end
  end

  add_model_callback(User, :before_create) do
    if SiteSetting.phone_verification_enabled
      self.custom_fields["needs_verify_phone"] = "true"
    end
    #Jobs.enqueue_in(3, :set_user_needs_verify_phone, user_id: self.id)
  end

}

register_asset 'stylesheets/phone-verification.scss'
register_asset 'javascripts/intlTelInput.min.js'