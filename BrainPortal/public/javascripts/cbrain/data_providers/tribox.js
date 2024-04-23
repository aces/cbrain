//
// <%-
// #
// # CBRAIN Project
// #
// # Copyright (C) 2008-2012
// # The Royal Institution for the Advancement of Learning
// # McGill University
// #
// # This program is free software: you can redistribute it and/or modify
// # it under the terms of the GNU General Public License as published by
// # the Free Software Foundation, either version 3 of the License, or
// # (at your option) any later version.
// #
// # This program is distributed in the hope that it will be useful,
// # but WITHOUT ANY WARRANTY; without even the implied warranty of
// # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// # GNU General Public License for more details.
// #
// # You should have received a copy of the GNU General Public License
// # along with this program.  If not, see <http://www.gnu.org/licenses/>.
// #
// -%>

// JS to add indetermitate state to certanain checkboxes

// indeterminate state on can be set with JS
// all elements with empty value are set as indeterminate
jQuery(".show_table_edit_link").on("click",
    function() {
        $(".dp_box.indeterminate").each(
            function () {
                $(this).prop("indeterminate", true);
                let prev = $(this).prev();
                let val = prev.val();
                if ( val != '' ) {
                    prev.val("");
                }
            }
        );
        $(".dp_box.indeterminate").click(
            function () {
                $(this).val('copy');
                let prev = $(this).prev();
                prev.val("disable");                            }
        )




    }
);

// make indeterminate elements determinate again
jQuery(".show_table").on("click code-change", ".dp_box.indeterminate", function() {
    $(this).each(function() {
        // $(this).prop("indeterminate", false); // usually happens automatically
        $(this).val('copy')
        // change value of hidden element back to disabled
        $(this).prev().val("disabled")
    });
});


// makes indetermintate checkbox determinate
// function determinize(el)  {
//     el.prop("indeterminate", false);
//     // change value of hidden element
//     el.prev().val('copy');
// }

// all elements with empty value are set as indeterminate






