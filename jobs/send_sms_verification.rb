module Jobs

  class SendSmsVerification < Jobs::Base

    def execute(args)
      return if !PhoneVerificationHelper.sms_provider_is_set?
      return if args[:user_id].blank?

      user = User.where(id: args[:user_id]).first
      return if !PhoneVerificationHelper.send_sms_verification?(user)

      phone_numbers = user.custom_fields["phone_numbers"]
      code          = user.custom_fields["verification_code"]
      return if (phone_numbers.blank? || code.blank?)

      PhoneVerificationHelper.send_sms(phone_numbers, I18n.t("phone_verification.sms_content", code: code))
    end    
    
  end
end