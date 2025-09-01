return [[
    function expandAll(button) {
        var detailsContainer = button.parentElement.parentElement;
        var nestedDetails = detailsContainer.querySelectorAll('details');
        nestedDetails.forEach(function(detail) {
            detail.open = true;
        });
    }

    function collapseAll(button) {
        var detailsContainer = button.parentElement.parentElement;
        var nestedDetails = detailsContainer.querySelectorAll('details');
        nestedDetails.forEach(function(detail) {
            detail.open = false;
        });
        detailsContainer.open = false;
    }
]]
