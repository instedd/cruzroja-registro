var navigatePage = (page, config) => {
  return (e) => {
    e.preventDefault();

    var params = filterParams(config.filters);

    if (config.pagination) {
      var paginationData = $(".pager").data();
      var targetPage = paginationData[page];

      if (targetPage) {
        params = params.concat([["page", targetPage]])
        fetch(config, params)
      }
    } else {
      fetch(config, params)
    }
  }
}

var buildUri = (endpoint, params) => {
  var query = params.map(kv => `${kv[0]}=${encodeURIComponent(kv[1])}`)
      .join("&")

  return endpoint + "?" + query;
}

var fetch = (config, params) => {
  params = params.concat([["raw", 1]])

  $.ajax({
    url: buildUri(config.endpoint, params),
    type: "get",
    success: function (data) {
      $('#replaceable').html(data)

      initPagination(config)
      bindItemClick(config)

      if (config.afterFetch) {
        config.afterFetch()
      }
    }
  });
}

var filterParams = (filters) => {
  return filters.map(f => [f.name, f.getValue()])
    .filter(kv => kv[1])
}

var initPagination = (config) => {
  if (config.pagination) {
    var pager = $(".pager")
    pager.find(".pager-left").on("click", navigatePage("previousPage", config))
    pager.find(".pager-right").on("click", navigatePage("nextPage", config))
  }
}

var bindItemClick = (config) => {
  if (config.onItemClick) {
    $('.listing table tr').on("click", config.onItemClick)
  }
}

export var Filters = {
  init : (config) => {
    var applyFilters = navigatePage("currentPage", config);

    initPagination(config)
    bindItemClick(config)

    config.filters.forEach((filter) => {
      filter.subscribe(applyFilters);
    });

    if(config.downloadEndpoint) {
      $("#download").on("click", () => {
        document.location.href = buildUri(config.downloadEndpoint, filterParams(config.filters))
      })
    }
  },

  jQueryFilter: (name, selector, changeEvent) => {
    return {
      name: name,
      getValue: () => { return $(selector).val() },
      subscribe: (handler) => { $(selector).on(changeEvent, handler) }
    }
  }
}
