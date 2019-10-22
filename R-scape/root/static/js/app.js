$(document).ready(function () {
  $('table thead .nosort').data('sorter', false);
  $('.outresults').tablesorter({ sortReset : true });
  $('.powerresults').tablesorter({ sortReset : true });

  // set up the rotating descriptions when selecting a mode on the home page.
  $('.mode-desc').hide();
  // show the selected one
  var selected = $("input[name$='mode']:checked").val();
  $('#mode-desc'+ selected).show();
  // We only want to show one at a time as they take up a lot of space.
  $("input[name$='mode']").click(function() {
    var mode = $(this).val();
    // mark all descriptions as hidden
    $('.mode-desc').hide();
    // show the selected one
    $('#mode-desc'+ mode).show();
  });
});
