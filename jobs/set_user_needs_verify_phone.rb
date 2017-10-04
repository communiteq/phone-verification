module Jobs

  class SetUserNeedsVerifyPhone < Jobs::Base

    def execute(args)
      return if args[:user_id].blank?

      user = User.where(id: args[:user_id]).first

      return if !user

      if PhoneVerificationHelper.needs_verify_phone?(user)
        user.custom_fields["needs_verify_phone"] = "true"
        user.save!
      end
    end
    
  end
    
end