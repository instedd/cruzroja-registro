import { Listings } from "./listings";

var initAdminSelector = (containerId, initialData) => {
  var encodeChips = (chips) => {
    return chips.map(c => c.tag).join("|")
  }

  var syncChips = (e, chip) => {
    var data = chipContainer.material_chip('data')
    var encodedData = encodeChips(data)

    formInput.val(encodedData)
  }

  if (!initialData) {
    throw `Invalid initial data for ${containerId} selector`
  }

  var container = $(`#${containerId}`)
  var chipContainer = $(container).find('.selector-chips')
  var formInput = $(container).find("input")

  if (!chipContainer.length || !formInput.length) {
    throw "Invalid markup for chip container"
  }

  chipContainer.material_chip({
    secondaryPlaceholder: '+Email',
    placeholder: ' +Email',
    data: initialData.map(email => { return { tag: email }})
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
     if (window.branchAdmins) {
       initAdminSelector('admins-selector', branchAdmins)
     }

     if (window.branchClerks) {
       initAdminSelector('clerks-selector', branchClerks)
     }
   });
  }};
