// static/loader.js
(function () {
    const LOG_PREFIX = "[custom-loader]";

    /**
     * Utility: wait for a selector to exist in the DOM
     */
    function waitForSelector(selector, root = document, timeout = 10000) {
        return new Promise((resolve, reject) => {
            const found = root.querySelector(selector);
            if (found) return resolve(found);

            const observer = new MutationObserver(() => {
                const el = root.querySelector(selector);
                if (el) {
                    observer.disconnect();
                    resolve(el);
                }
            });

            observer.observe(
                root === document ? document.documentElement : root,
                { childList: true, subtree: true }
            );

            if (timeout) {
                setTimeout(() => {
                    observer.disconnect();
                    reject(new Error("Timeout waiting for " + selector));
                }, timeout);
            }
        });
    }

    /* ---------------------------------------
     * 1) Rename "Open WebUI" -> "OpenAwesome"
     * ------------------------------------- */

    waitForSelector("#sidebar-webui-name")
    .then((el) => {
        el.textContent = "OpenAwesome";
    })
    .catch((err) => console.warn(LOG_PREFIX, err.message));

    /* ---------------------------------------
     * 2) Drive talking avatar ONLY while
     *    text is streaming in .chat-assistant
     *    #response-content-container
     * ------------------------------------- */

    let lastAssistantLen = 0;

    function getLatestAssistantText() {
        // One "message" per .chat-assistant
        const assistants = document.querySelectorAll(".chat-assistant");

        if (!assistants.length) return "";

        const lastAssistant = assistants[assistants.length - 1];

        // In your DOM, the real content is under this id:
        // <div class="w-full flex flex-col relative" id="response-content-container">
        const content =
        lastAssistant.querySelector("#response-content-container") ||
        // just in case the id ends up with a hash suffix in some versions:
        lastAssistant.querySelector('[id^="response-content-container"]');

        if (!content) return "";

        // innerText so we get line breaks, etc.
        return (content.innerText || "").trim();
    }

    function updateTalkingState() {
        const body = document.body;

        // This matches the Stop button you showed earlier in your CSS:
        // button.bg-white.rounded-full.p-1.5 inside the message input bar.
        const stopBtn = document.querySelector(
            "#message-input-container button.bg-white.rounded-full.p-1\\.5"
        );

        const assistantText = getLatestAssistantText();
        const currentLen = assistantText.length;

        // We only want "talking" when:
        //  - Stop button exists (streaming in progress), AND
        //  - response-content-container has some text, AND
        //  - that text is still growing vs the last check
        const shouldTalk =
        !!stopBtn && currentLen > 0 && currentLen >= lastAssistantLen;

        if (shouldTalk) {
            body.classList.add("avatar-talking");
        } else if (!stopBtn || currentLen === 0) {
            // If there's no stop button OR no assistant text, stop talking
            body.classList.remove("avatar-talking");
        }

        lastAssistantLen = currentLen;
    }

    // Wait for the message input area to appear, then start polling
    waitForSelector("#message-input-container")
    .then(() => {
        updateTalkingState();                // initial check
        setInterval(updateTalkingState, 150); // ~7 fps
    })
    .catch((err) => console.warn(LOG_PREFIX, err.message));
})();
