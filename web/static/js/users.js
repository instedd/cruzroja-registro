import { Listings } from "./listings";

export var Users = {
  init: function() {
    if ($("#users.listing").length) {
      Listings.init({
        endpoint: "/usuarios/filter",

        downloadEndpoint: "/usuarios/descargar",

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
