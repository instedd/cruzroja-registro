import debounce from './debounce';

var branchesAutocompleteData = function(branches) {
  var res = {}
  branches.forEach(b => {
    res[b["name"]] = null
  })
  return res;
}

var indexByName = function(branches) {
  var res = {}
  branches.forEach(b => {
    res[b["name"]] = b
  })
  return res;
}

export var BranchSelector = {
  init : (branchList, config) => {
    if (!branchList) {
      throw "Invalid branch list provided to branch selector";
    }

    if (!config) {
      config = {}
    }

    var input = $('input.autocomplete');

    $(() => {
      if(input.length > 0) {
        input.autocomplete({
          data: branchesAutocompleteData(branchList)
        });
      }

      if (config.onSelect) {
        var branchIndex = indexByName(branchList);

        var onSelect = () => {
          var text = input.val();
          var branch = branchIndex[text];
          config.onSelect(branch);
        }

        input.bind('change', debounce(onSelect, 200, false))

        onSelect();
      }
    })
  }}
