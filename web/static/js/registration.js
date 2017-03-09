import { RegistrationDateSelector } from "./registration_date_selector";


let initColaborationSettings = (container) => {
  let oneYearAgo = new Date(new Date().setFullYear(new Date().getFullYear() - 1))
  let paymentWarning = container.find("#payment-warning")

  let refreshWarning = (opt) => {
    paymentWarning.toggle(opt.shouldDisplayWarning())
  }

  let select = (opt) => {
    opt.container.addClass("visible")
    refreshWarning(opt)
  }

  let opts = [
    {
      id: "new-colaboration-option",
      init: function() {
        this.container = container.find(`#${this.id}`),

        this.roleInput = this.container.find("select[name='new_colaboration_role']")
        this.roleInput.on('change', () => { refreshWarning(this) })
      },
      shouldDisplayWarning: function() {
        return this.roleInput.val() == "associate"
      }
    },
    {
      id: "current-volunteer-option",
      init: function() {
        this.container = container.find(`#${this.id}`)

        this.datePicker = this.container.find(".datepicker").pickadate('picker')
        this.datePicker.on('set', () => { refreshWarning(this) })

        this.roleInput = this.container.find("select[name='current_volunteer_desired_role']")
        this.roleInput.on('change', () => { refreshWarning(this) })

        if (!this.datePicker.get()) {
          this.datePicker.set('select', new Date())
        }
      },
      shouldDisplayWarning: function() {
        let selectedDate = this.datePicker.get('select').obj
        let desiredRole = this.roleInput.val()

        return (desiredRole == "associate") && (selectedDate > oneYearAgo)
      }
    },
    {
      id: "current-associate-option",
      init: function() {
        this.container = container.find(`#${this.id}`)
      },
      shouldDisplayWarning: function() {
        return false
      }
    },
  ]

  let optionChanged = (e) => {
    let optId = $(e.target).closest(".option").attr("id")

    opts.forEach((opt) => {
      if (opt.id == optId) {
        select(opt)
      } else {
        opt.container.removeClass("visible")
      }
    })
  }

  let prefillSelection = () => {
    let optId = $(".option input[checked=checked]").closest(".option").attr("id")

    opts.forEach((opt) => {
      if (opt.id == optId) {
        select(opt)
      }
    })
  }

  container.find("input[type=radio]").bind('change', optionChanged)
  opts.forEach((opt) => opt.init())
  prefillSelection()
}

export var Registration = {
  init: function() {
    $("#register").each(() => {
      initColaborationSettings($("#colaboration-kinds"))
    })
  }};
