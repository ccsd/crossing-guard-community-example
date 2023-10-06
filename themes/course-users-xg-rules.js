/**
// @name        Crossing Guard Rules of Reconciliation
// @namespace   https://github.com/ccsd/crossing-guard-community-example 
// @description adds button for course/users, should explain your rules
//
**/
(function () {
  "use strict";

  if (/\/courses\/\d+\/users/.test(window.location.pathname)) {
    var observer = new MutationObserver(function () {
      $("#addUsers").after(
        '<div class="text-right clear" style="padding-top: 0.25em"><button id="showCrossingRules" class="btn btn-primary btn-small pull-right">Show Crossing Guard Rules</button></div>'
      );

      $(document).on("click", "#showCrossingRules", function (e) {
        e.preventDefault();

        $("#crossing-guard-rules").dialog({
          modal: true,
          title: "Crossing Guard Rules of Reconciliation",
          width: 500,
        });
      });

      $("#content").append(`<div style="display: none">
        <div id="crossing-guard-rules">
          <ul>
            <li>Students cannot be anything but a student role in the course</li>
            <li>Students cannot be removed from a Canvas course when they have an active enrollment in the SIS.</li>
            <li>Students can be manually enrolled (and removed) in a course via Canvas</li>
            <li>Teacher of Record cannot be removed from a course via Canvas</li>
            <li>Employees can have any role</li>
            <li>Non-[Instituion] accounts can only have the Observer role</li>
          </ul>
        </div>
        </div>`);

      observer.disconnect();
    });

    observer.observe(document.getElementById("content"), {
      childList: true,
      subtree: true,
    });
  }
})();
