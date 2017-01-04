import { Filters } from "./filters";

export var Branches = {
  init: function() {
    var listingContainer = $("#branches.listing");

    if (listingContainer) {
      Filters.init({
        endpoint: "/branches/",
        pagination: true,
        filters: []
      });
    }
  }
};
