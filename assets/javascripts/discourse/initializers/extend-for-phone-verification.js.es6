import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'phone_verification',
  initialize(c) {

    const ss = c.lookup('site-settings:main');


    withPluginApi('0.1', api => {

      const currentUser = api.getCurrentUser();
      console.log(currentUser);

      api.onPageChange((url, title) => {
        const path = url.split("?")[0];

        if (path == "/phone-verification" || path == "/phone-verification/") {
          if (currentUser && ss.phone_verification_enabled) {

            if (!currentUser.get("phone-verification.is_needs_verify_phone")) {
              window.location = "/";
            }

          } else {
            window.location = "/";
          }
        } else {
          if (currentUser && currentUser.get("phone-verification.is_needs_verify_phone")) {
            window.location = "/phone-verification";
          }
        }
      });

    });
  }
}