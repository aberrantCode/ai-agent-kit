// entrypoints/content.ts
//
// Starter content script entrypoint. WXT auto-registers any file under
// entrypoints/ that calls `defineContentScript`
// (see ../../references/wxt-config.md#content-scripts). Replace `matches`
// with the target site(s) and `main()` with real DOM extraction / messaging
// logic — see ../../references/messaging.md for the background<->content
// protocol and ../../references/mv3-permissions.md for the host_permissions
// this requires.
export default defineContentScript({
  // Replace with the site(s) this content script should run on.
  matches: ['https://example.com/*'],

  main(ctx) {
    console.log('Content script loaded on', window.location.href);

    // Cleanup hook — fires when the script is invalidated (e.g. extension
    // reload during development).
    ctx.onInvalidated(() => {
      // Remove any listeners, observers, or injected UI here.
    });
  },
});
