var build_query = function() {
  var query = "/users/filter?"
  if(value_for('role'))
    query += "role=" + value_for('role') + "&"
  if(value_for('status'))
    query += "status=" + value_for('status') + "&"
  if(value_for('branch'))
    query += "branch=" + value_for('branch')
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
  }
  return res;
}

export var Filters = {
  activateSelects: function() {
    $('select').material_select();
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
  }
}
