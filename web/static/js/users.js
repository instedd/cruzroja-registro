import { Listings } from "./listings";

export var Users = {
  init: function() {
    $("#users").each(() =>
      Listings.init({
        selector: "#users.listing",
        endpoint: "/usuarios/filter",
        downloadEndpoint: "/usuarios/descargar",
        pagination: true,
        filters: [
          Listings.onEventFilter("role", "#role", "change"),
          Listings.onEventFilter("status", "#status", "change"),
          Listings.onEventFilter("branch", "#branch", "change"),
          Listings.onEventFilter("name", "#user-name", "input")
        ],
        onItemClick: (e) => {
          document.location.href = $(e.target).closest("tr").data("href")
        }
      })
    )}};
