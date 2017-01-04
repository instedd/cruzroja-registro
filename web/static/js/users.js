import { Listings } from "./listings";

var branchesAutocompleteData = (branches) => {
  var res = {}
  branches.forEach(e => {
    res[e["name"]] = null
  })
  return res;
}

export var Users = {
  init: function() {
    if ($("#users.listing").length) {
      $(function() {
        $('input.autocomplete').autocomplete({
          data: branchesAutocompleteData(branches)
        });
      });

      Listings.init({
        endpoint: "/users/filter",

        downloadEndpoint: "/users/download",

        pagination: true,

        filters: [
          Listings.jQueryFilter("role", "#role", "change"),
          Listings.jQueryFilter("status", "#status", "change"),
          Listings.jQueryFilter("branch", "#branch", "change"),
          Listings.jQueryFilter("name", "#user-name", "input")
        ],

        onItemClick: (e) => {
          document.location.href = $(e.target).closest("tr").data("href")
        }
      });
    }
  }
};
