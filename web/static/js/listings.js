var navigatePage = (page, config) => {
  return (e) => {
    e.preventDefault();

    var params = filterParams(config.filters);

    if (config.pagination) {
      var paginationData = config.container.find(".pager").data();

      var targetPage = paginationData[page] || 1;

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
    type: "get"
  }).done( data => {
    config.container.find('#replaceable').html(data)

    initPagination(config)
    bindItemClick(config)

    if (config.afterFetch) {
      config.afterFetch()
    }
  }).fail( data => {
    Materialize.toast("Hubo un error al actualizar los datos.", 8000)
  })
  ;
}

var filterParams = (filters) => {
  return filters.map(f => [f.name, f.getValue()])
    .filter(kv => kv[1])
}

var initPagination = (config) => {
  if (config.pagination) {
    var pager = config.container.find(".pager")

    pager.find(".pager-left")
         .on("click", navigatePage("previousPage", config))

    pager.find(".pager-right")
         .on("click", navigatePage("nextPage", config))

    pager.find(".disabled")
         .on("click", (e) => e.preventDefault())
  }
}

var bindItemClick = (config) => {
  if (config.onItemClick) {
    config.container.find('tbody tr').on("click", config.onItemClick)
  }
}

export var Listings = {
  init : (config) => {
    var container = $(config.selector);

    if (container.length) {
      config.container = container;
    } else {
      return;
    }

    var applyFilters = navigatePage("initial", config);

    initPagination(config)
    bindItemClick(config)

    config.filters.forEach((filter) => {
      filter.subscribe(applyFilters);
    });

    if(config.downloadEndpoint) {
      config.container.find("#download").on("click", () => {
        document.location.href = buildUri(config.downloadEndpoint, filterParams(config.filters))
      })
    }
  },

  onEventFilter: (name, selector, changeEvent) => {
    return {
      name: name,
      getValue: () => { return $(selector).val() },
      subscribe: (handler) => { $(selector).on(changeEvent, handler) }
    }
  }
}
