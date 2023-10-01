import htmx from 'htmx.org';

(function () {
  function startTimer(element: HTMLElement, duration: number) {
    const timerId = setTimeout(function () {
      element.dataset.state = 'hidden';
    }, duration);
    element.dataset.timer = String(timerId);
  }

  htmx.defineExtension('flash-message', {
    onEvent: function (name, event) {
      var element = event.target;
      if (name === 'htmx:afterProcessNode' && element instanceof HTMLElement) {
        element.addEventListener('mouseleave', function () {
          clearTimeout(Number(element.dataset.timer));
          startTimer(element, 1500);
        });

        element.addEventListener('mouseenter', function () {
          clearTimeout(element.dataset.timer);
        });

        // Setup initial timeout
        startTimer(element, 4000);
      }
    },
  });
})();
