import { Listings } from "./listings";

var initAdminSelector = () => {
  var encodeChips = (chips) => {
    return chips.map(c => c.tag).join("|")
  }

  var syncChips = (e, chip) => {
    var data = chipContainer.material_chip('data')
    var encodedData = encodeChips(data)

    formInput.val(encodedData)
  }

  if (!branchAdmins) {
    throw "Expected global 'branchAdmins' variable to initialize admins selector"
  }

  var initialData = branchAdmins.map(email => { return { tag: email }})
  var chipContainer = $('.admin-chips')
  var formInput = $("input[name='admin_emails']")

  if (!chipContainer.length || !formInput.length) {
    throw "Invalid markup for chip container"
  }

  chipContainer.material_chip({
    placeholder: ' +Email',
    data: initialData
  });

  chipContainer.on('chip.add', syncChips);
  chipContainer.on('chip.delete', syncChips);

  syncChips()
}

export var Branches = {
  init: function() {
    $("#branches").each(() =>
      Listings.init({
        selector: "#branches.listing",
        endpoint: "/filiales/",
        pagination: true,
        filters: [],
        onItemClick: (e) => {
          document.location.href = $(e.target).closest("tr").data("href")
        }
      })
   )

   $("#branch-details").each(() => {
     initAdminSelector()
   });
  }};
