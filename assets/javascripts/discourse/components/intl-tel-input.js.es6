export default Ember.Component.extend({

  tagName: "span",

  // isNotValidNumber: false,

  // updateIsNotValidNumber() {
  //   this.set("isNotValidNumber", !Ember.$(".phone-numbers-input").intlTelInput("isValidNumber"));
  // },

  // isSaveButtonDisabled: function() {
  //   this.updateIsNotValidNumber();
  //   return this.get("isNotValidNumber");
  // }.property("phoneNumbers"),

  didRender() {
    Ember.$(".phone-numbers-input").intlTelInput({
      utilsScript: "https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/12.1.0/js/utils.js"
    });

    // this.updateIsNotValidNumber();

    // let self = this;

    // Ember.$(".intl-tel-input .country-list li.country").on("click", () => {
    //   console.log(Ember.$(".phone-numbers-input").intlTelInput("isValidNumber"));
    //   self.updateIsNotValidNumber();
    // });
  },

  willDestroyElement() {
    Ember.$(".phone-numbers-input").intlTelInput("destroy");
  },

  actions: {
    save() {
      const $intTel = Ember.$(".phone-numbers-input");
      if ($intTel.intlTelInput("isValidNumber")) {
        this.sendAction("savePhoneNumbers", $intTel.intlTelInput("getNumber"));
      } else {
        bootbox.alert(I18n.t("phone_verification.phone_numbers_not_valid"));
      }
    }
  }
});