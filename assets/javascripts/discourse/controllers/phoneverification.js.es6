import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  errorMsg: null,
  performingAction: false,
  verificationCode: "",

  isShowEnterPhone: function() {
    return (this.get("model.template") == "enter_phone");
  }.property("model.template"),

  isShowEnterCode: function() {
    return (this.get("model.template") == "enter_code");
  }.property("model.template"),

  isShowResendButton: function() {
    return (this.get("model.send_code_left") > 0);
  }.property("model.send_code_left"),

  isShowEditButton: function() {
    return (this.get("model.edit_phone_numbers_left") > 0);
  }.property("model.edit_phone_numbers_left"),

  isVerifyCodeButtonDisabled: function() {
    return !this.get("verificationCode");
  }.property("verificationCode"),

  showSuccessMsg: function() {
    return (this.get("model.template") == "success");
  }.property("model.template"),

  actions: {
    editPhoneNumbers() {
      this.set("errorMsg", null);
      this.set("model.template", "enter_phone");
    },
    savePhoneNumbers(ph) {
      this.toggleProperty("performingAction");
      this.set("errorMsg", null);
      let self = this;
      ajax("/phone-verification/set_phone_numbers.json", {
        type: "POST",
        data: {
          phone_numbers: ph
        }
      }).catch(popupAjaxError).then(result => {
        if (result.status == "success") {
          self.set("model", result.data);
        } else {
          self.set("errorMsg", result.data);
        }
      }).finally(() => {
        self.toggleProperty("performingAction");
      });
    },
    resendCode() {
      this.toggleProperty("performingAction");
      this.set("errorMsg", null);
      let self = this;
      ajax("/phone-verification/send_code.json").catch(popupAjaxError).then(result => {
        if (result.status == "success") {
          self.set("model", result.data);
        } else {
          self.set("errorMsg", result.data);
        }
      }).finally(() => {
        self.toggleProperty("performingAction");
      });
    },
    verifyCode() {
      this.toggleProperty("performingAction");
      this.set("errorMsg", null);
      let self = this;
      ajax("/phone-verification/verify_code.json", {
        type: "POST",
        data: {
          verification_code: this.get("verificationCode")
        }
      }).catch(popupAjaxError).then(result => {
        if (result.status == "success") {
          self.set("model.template", "success");
          window.location = "/";
        } else {
          self.set("errorMsg", result.data);
        }
      }).finally(() => {
        self.toggleProperty("performingAction");
      });
    }
  }

});