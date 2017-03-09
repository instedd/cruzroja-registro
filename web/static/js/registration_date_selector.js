export var RegistrationDateSelector = {
  init : (selector) => {
    let container = $(selector)
    let checkbox = container.find("input[type='checkbox']")
    let inputContainer = container.find(".registration_date")

    checkbox.on("change", function() {
      inputContainer.toggleClass("hide")
      inputContainer.find("iput").val("")
    })
  }
}
