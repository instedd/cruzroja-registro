import { Listings } from "./listings";

export var Branches = {
  init: function() {
    var listingContainer = $("#branches.listing");

    if (listingContainer.length) {
      Listings.init({
        endpoint: "/filiales/",
        pagination: true,
        filters: [],
        onItemClick: (e) => {
          document.location.href = $(e.target).closest("tr").data("href")
        }
      });
    }
  }
};
