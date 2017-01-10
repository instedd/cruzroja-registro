import { Listings } from "./listings";

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
    )}};
