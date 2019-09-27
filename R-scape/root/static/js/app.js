/*********************sortable tables***********************/
$.fn.sortable = function(){
  var table = $(this);
  // attach onclick events to thead
  $(this).find('thead .sortable').bind('click', function() {

    // removed sorted from all columns
    $(this).closest('thead').find('.sorted').removeClass('sorted');

    // mark this as sorted for styling
    $(this).addClass('sorted');

    // need to figure out which column we are sorting on
    var column_number = $(this).attr('data-column');
    // build array to manipulate with the sort
    var rows = [];
    var row_total = table.find('tbody tr').size();

    for (var row = 0; row < row_total; row++) {
      rows[row] = [];
    }

    table.find('tbody tr').each(function(i){
      rows[i][0] = $(this).find('td').eq(column_number).text();
      rows[i][1] = this;
    });

    // now sort the rows array
    if ($(this).hasClass('numeric')) {
      rows.sort(function (a, b) { return a[0] - b[0] ; });
    }
    else if ($(this).hasClass('evalue')) {
      rows.sort(function (a, b) { return parseFloat(a[0]) - parseFloat(b[0]) ; });
    }
    else {
      rows.sort();
    }

    //now remove each one from the dom and put it at the end of the table.
    for (var row2 = 0; row2 < row_total; row2++) {
      var meta = rows[row2][1];
      var alignment = $(rows[row2][1]).next('.alignment');

      $(meta).detach();
      $(alignment).detach();

      table.find('tbody').append(meta).append(alignment);
    }
  });
};

$(document).ready(function () {
  $('.outresults').sortable();

  // set up the rotating descriptions when selecting a mode on the home page.
  $('.mode-desc').hide();
  // show the selected on
  $('#mode-desc1').show();
  // We only want to show one at a time as they take up a lot of space.
  $("input[name$='mode']").click(function() {
    var mode = $(this).val();
    // mark all descriptions as hidden
    $('.mode-desc').hide();
    // show the selected one
    $('#mode-desc'+ mode).show();
  });
});
