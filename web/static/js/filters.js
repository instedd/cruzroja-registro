var build_query = function(endpoint) {
  if(endpoint == null)
    endpoint = "filter"
  var query = "/users/" + endpoint + "?"
  if(value_for('role'))
    query += "role=" + value_for('role') + "&"
  if(value_for('status'))
    query += "status=" + value_for('status') + "&"
  if(value_for('branch'))
    query += "branch=" + value_for('branch') + "&"
  if(value_for('name'))
    query += "name=" + value_for('name')
  return query;
}

var value_for = function(name) {
  var res = ""
  switch(name) {
    case 'role':
      res = $('#role').val();
      break;
    case 'status':
      res = $('#status').val();
      break;
    case 'branch':
      res = $('#branch').val();
      break;
    case 'name':
      res = $('#user-name').val();
  }
  return res;
}

var setup = function(data) {
  var res = {}
  $.each(data, function(i,e) {
    res[e["name"]] = null
  })
  return res;
}

export var Filters = {
  activateSelects: function() {
    $('select').material_select();
  },
  activateAutocompletes: function() {
    $( function() {
      var inputs = $('input.autocomplete')
      if(inputs.length > 0 && branches) {
        inputs.autocomplete({
          data: setup(branches)
        });
      }
    })
  },
  setupFilters: function(){
    $('#role, #branch, #status').on("change", function() {
      $.ajax({
        url: build_query(),
        type: "get",
        success: function (data) {
          $('tbody#replaceable').html(data)
        }
      });
    })
    $('#user-name').on("input", function() {
      $.ajax({
        url: build_query(),
        type: "get",
        success: function (data) {
          $('tbody#replaceable').html(data)
        }
      });
    })
  },
  setupCSVDownload: function() {
    $('#download').on("click", function() {
      document.location.href = build_query("download")
    })
  }
}
