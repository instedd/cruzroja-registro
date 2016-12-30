var build_query = function() {
  return "/users/filter?role=" + value_for('role') + "&status=" + value_for('status') + "&branch=" + value_for('branch');
}

var value_for = function(name) {
  switch(name) {
    case 'role':
      $('#role').val();
      break;
    case 'status':
      $('#status').val();
      break;
    case 'branch':
      $('#branch').val();
      break;
  }
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
        dataType: "json",
        success: function (data) {
          $('tbody#replaceable').html(data)
        }
      });
    })
  }
}
