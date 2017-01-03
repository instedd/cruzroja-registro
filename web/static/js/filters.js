var build_query = function() {
  var query = "/users/filter?"
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
  console.log(res)
  return res;
}

export var Filters = {
  activateSelects: function() {
    $('select').material_select();
  },
  activateAutocomplete: function() {
    $('input.autocomplete').autocomplete({
      data: setup(branches)
    });
  },
  setupFilters: function(){
    $('#role, #branch, #status, #user-name').on("change input", function() {
      $.ajax({
        url: build_query(),
        type: "get",
        success: function (data) {
          $('tbody#replaceable').html(data)
        }
      });
    })
  }
}
