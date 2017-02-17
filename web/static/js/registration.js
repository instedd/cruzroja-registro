export var Registration = {
  init: function() {
    $('#old_volunteer').on("change", function() {
      $('.registration_date').toggleClass("hide")
      $('.registration_date input').val("")
    })
  }};
