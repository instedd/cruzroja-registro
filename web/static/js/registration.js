import { RegistrationDateSelector } from "./registration_date_selector";

let initColaborationSettings = (container) => {
  let oneYearAgo = new Date(new Date().setFullYear(new Date().getFullYear() - 1))
  let datePicker = container.find(".datepicker").pickadate('picker')
  let desiredRoleSelect = $("select[name='current_volunteer[desired_role]']")
  let paymentWarning = container.find(".payment-warning")

  let unselect = (opt) => {
    opt.removeClass("visible")
  }

  let select = (opt) => {
    opt = $(opt)
    opt.addClass("visible")

    if (!datePicker.get()) {
      datePicker.set('select', new Date())
    }
  }

  let optionChanged = (e) => {
    let opt = $(e.target).closest(".option")

    unselect($(".option"))
    select(opt)
  }

  let refreshWarning = () => {
    let selectedDate = datePicker.get('select').obj
    let desiredRole = desiredRoleSelect.val()
    let displayWarning = (desiredRole == "associate") && (selectedDate > oneYearAgo)

    paymentWarning.toggle(displayWarning)
  }

  container.find("input[type=radio]").bind('change', optionChanged)
  select(container.find("input[type=radio]:checked").siblings(".inline-settings"))

  datePicker.on('set', refreshWarning)
  desiredRoleSelect.on('change', refreshWarning)
}

export var Registration = {
  init: function() {
    $("#register").each(() => {
      initColaborationSettings($("#colaboration-kinds"))
    })
  }};
