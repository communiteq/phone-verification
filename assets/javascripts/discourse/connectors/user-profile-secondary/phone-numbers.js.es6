export default {
  shouldRender({model}, component) {
    return component.siteSettings.phone_verification_enabled && component.currentUser && component.currentUser.get("admin") && !model.get("phone_verification.hide");
  },
  setupComponent({model}, component) {

  },
  actions: {

  }
};