import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Component.extend({ 

  savingPhoneNumbers: false,
  sendingCode: false,
  canSendCode: false,
  editingPhone: false,
  prevPhone: null,

  isVerified: function() {
    return this.get("model.phone_verification.needs_verify_phone") == "verified";
  }.property("model.phone_verification.needs_verify_phone"),

  isNotVerified: function() {
    return this.get("model.phone_verification.needs_verify_phone") == "true";
  }.property("model.phone_verification.needs_verify_phone"),

  notEditingPhone: function() {
    return !this.get("editingPhone");
  }.property("editingPhone"),  

  actions: {
    editPhone() {
      this.set("prevPhone", this.get("model.phone_verification.phone_numbers"));
      this.toggleProperty("editingPhone");
    },

    cancelEditingPhone() {
      this.toggleProperty("editingPhone");
      this.set("model.phone_verification.phone_numbers", this.get("prevPhone"));
    },

    sendCode() {
      this.toggleProperty("sendingCode");

      let self = this;

      ajax("/phone-verification/admin_send_code.json", {
        data: {
          id: self.get("model.id")
        }
      }).catch(popupAjaxError).then((result) => {
        if (result.status == "success") {
          self.set("model.phone_verification.needs_verify_phone", "true");
          bootbox.alert(I18n.t("phone_verification.admin.verification_code_sent", {phone_numbers: self.get("model.phone_verification.phone_numbers")}));
        } else {
          bootbox.alert(result.data);
        }
      }).finally(() => {
        this.toggleProperty("sendingCode");
      });
    },

    savePhoneNumbers(ph) {
      this.toggleProperty("savingPhoneNumbers");

      let self = this;

      ajax("/phone-verification/admin_set_phone_numbers.json", {
        type: "POST",
        data: {
          id: self.get("model.id"),
          phone_numbers: ph
        }
      }).catch(popupAjaxError).then((result) => {
        if (result.status == "success") {
          self.set("model.phone_verification", result.data);
          self.toggleProperty("editingPhone");
        } else {
          bootbox.alert(result.data);
        }
      }).finally(() => {
        this.toggleProperty("savingPhoneNumbers");
      });

    },
    setAsVerified() {
      this.commonAjax("set_as_verified");
    },

    forceVerification() {
      this.commonAjax("force_verification");
    },

    deletePhoneNumbers() {
      this.commonAjax("del_phone_numbers");
    }
  },

  commonAjax(path) {
    this.toggleProperty("sendingCode");

    let self = this;

    ajax(`/phone-verification/admin_${path}.json`, {
      data: {
        id: self.get("model.id")
      }
    }).catch(popupAjaxError).then((result) => {
      if (result.status == "success") {
        self.set("model.phone_verification", result.data);
      } else {
        bootbox.alert(result.data);
      }
    }).finally(() => {
      this.toggleProperty("sendingCode");
    });
  }

});