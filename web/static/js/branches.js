import { Listings } from "./listings";

export var Branches = {
  init: function() {
    var listingContainer = $("#branches.listing");

    if (listingContainer.length) {
      Listings.init({
        endpoint: "/branches/",
        pagination: true,
        filters: []
      });
    }
  }
};
