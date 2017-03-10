function changeSorting(field, config) {
  return (e) => {
    let header = config.container.find(`th[data-field=${field}]`)
    var direction

    if (header.hasClass("sort-desc")) {
      header.removeClass("sort-desc")
      direction = "asc"
    } else {
      header.removeClass("sort-asc")
      direction = "desc"
    }

    config.container.
      find("th")
      .removeClass("sort")
      .removeClass("sort-asc")
      .removeClass("sort-desc")

    header.addClass(`sort sort-${direction}`)

    loadResults("initial", config)
  }
}

function addSorting(params, config) {
  let sortingHeader = $($("th.sort")[0])
  let field = sortingHeader.data("field")

  if (sortingHeader.hasClass("sort-desc")) {
    return params.concat([["sorting", field], ["sorting_direction", "desc"]])
  } else {
    return params.concat([["sorting", field], ["sorting_direction", "asc"]])
  }
}

function loadResults(page, config) {
  var params = filterParams(config.filters);

  if (config.sorting) {
    params = addSorting(params, config)
  }

  params = params.concat([["raw", 1]])

  if (config.pagination) {
    let paginationData = config.container.find(".pager").data();
    let targetPage = paginationData[page] || 1;

    if (targetPage) {
      params = params.concat([["page", targetPage]])
      fetch(config, params)
    }
  } else {
    fetch(config, params)
  }
}

function navigateHandler(page, config) {
  return (e) => {
    e.preventDefault();
    loadResults(page, config)
  }
}

function buildUri(endpoint, params) {
  let query = params.map(kv => `${kv[0]}=${encodeURIComponent(kv[1])}`)
      .join("&")

  return endpoint + "?" + query;
}

function fetch(config, params) {
  params = params.concat([["raw", 1]])

  $.ajax({
    url: buildUri(config.endpoint, params),
    type: "get"
  }).done( data => {
    config.container.find('#replaceable').html(data)

    initBindings(config)

    if (config.afterFetch) {
      config.afterFetch()
    }
  }).fail( data => {
    Materialize.toast("Hubo un error al actualizar los datos.", 8000)
  })
  ;
}

function filterParams(filters) {
  return filters.map(f => [f.name, f.getValue()])
    .filter(kv => kv[1])
}

function initBindings(config) {
  if (config.pagination) {
    let pager = config.container.find(".pager")

    pager.find(".pager-left")
      .on("click", navigateHandler("previousPage", config))

    pager.find(".pager-right")
      .on("click", navigateHandler("nextPage", config))

    pager.find(".disabled")
      .on("click", (e) => e.preventDefault())
  }

  if (config.onItemClick) {
    config.container.find('tbody tr').on("click", config.onItemClick)
  }

  if (config.sorting) {
    config.container.find("th").each((i, e) => {
      let header = $(e)
      let field = header.data("field")

      header.bind("click", changeSorting(field, config))
    })
  }
}

export var Listings = {
  init : (config) => {
    let container = $(config.selector);

    if (container.length) {
      config.container = container;
    } else {
      return;
    }

    let applyFilters = navigateHandler("initial", config);

    initBindings(config)

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
