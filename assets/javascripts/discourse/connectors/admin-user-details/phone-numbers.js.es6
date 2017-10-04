export default {
  shouldRender({model}, component) {
    // only render if the plugin is enabled and the user is not an admin
    return component.siteSettings.phone_verification_enabled && !model.get("admin");
  },
  setupComponent({model}, component) {

  },
  actions: {

  }
};