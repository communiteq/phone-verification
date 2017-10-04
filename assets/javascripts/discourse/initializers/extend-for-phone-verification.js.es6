import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'phone_verification',
  initialize(c) {

    const ss = c.lookup('site-settings:main');


    withPluginApi('0.1', api => {

      const currentUser = api.getCurrentUser();

      api.onPageChange((url, title) => {
        const path = url.split("?")[0];

        if (path == "/phone-verification" || path == "/phone-verification/") {
          if (currentUser && ss.phone_verification_enabled) {
            console.log(currentUser);

            if (!currentUser.get("needs_verify_phone")) {
              window.location = "/";
            }

          } else {
            window.location = "/";
          }
        } else {
          if (currentUser && currentUser.get("needs_verify_phone")) {
            window.location = "/phone-verification";
          }
        }
      });

    });
  }
}