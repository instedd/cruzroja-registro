import { Filters } from "./filters";

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

      Filters.init({
        endpoint: "/users/filter",

        downloadEndpoint: "/users/download",

        filters: [
          Filters.jQueryFilter("role", "#role", "change"),
          Filters.jQueryFilter("status", "#status", "change"),
          Filters.jQueryFilter("branch", "#branch", "change"),
          Filters.jQueryFilter("name", "#user-name", "input")
        ]
      });
    }

    $('tbody#replaceable tr').on("click", function(){
      document.location.href = $(this).data("href")
    })
  }
};
