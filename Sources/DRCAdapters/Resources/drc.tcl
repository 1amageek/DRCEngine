# Headless DRC driver for the signoff harness.
#
# Magic emits free-text DRC explanations that carry no severity keyword, so this
# script normalizes them into lines the parser understands:
#
#   DRC_SUMMARY total=<n> cell=<name>
#   VIOLATION rule=<code> count=<n> message="<full rule text>"
#   DRC_DONE

proc normalize_message {value} {
    return [string map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"] $value]
}

if {![info exists env(DRC_CELL)]} {
    puts "ERROR rule=DRIVER message=\"DRC_CELL not set\""
    exit 1
}
set cell $env(DRC_CELL)

if {[info exists env(DRC_GDS)] && ![file exists $env(DRC_GDS)]} {
    puts "ERROR rule=DRIVER message=\"[normalize_message "GDS not found: $env(DRC_GDS)"]\""
    exit 1
}

if {[info exists env(DRC_MAG)] && ![file exists $env(DRC_MAG)]} {
    puts "ERROR rule=DRIVER message=\"[normalize_message "Magic layout not found: $env(DRC_MAG)"]\""
    exit 1
}

if {[catch {
    if {[info exists env(DRC_GDS)]} {
        gds read $env(DRC_GDS)
        load $cell
    } elseif {[info exists env(DRC_MAG)]} {
        load [file rootname $env(DRC_MAG)]
        if {[file rootname [file tail $env(DRC_MAG)]] ne $cell} {
            load $cell
        }
    } else {
        load $cell
    }
    if {[info exists env(MAGIC_DRC_STYLE)] && $env(MAGIC_DRC_STYLE) ne ""} {
        if {![regexp {^[A-Za-z0-9_.()_-]+$} $env(MAGIC_DRC_STYLE)]} {
            error "invalid MAGIC_DRC_STYLE: $env(MAGIC_DRC_STYLE)"
        }
        drc style $env(MAGIC_DRC_STYLE)
    }
    drc euclidean on
    drc on
    select top cell

    lassign [box values] llx lly urx ury
    if {[expr {($urx - $llx) * ($ury - $lly)}] <= 1} {
        error "cell not found or empty: $cell"
    }

    drc check
    drc catchup
    set total [drc list count total]
    puts "DRC_SUMMARY total=$total cell=$cell"

    set enumerated 0
    foreach {rule coords} [drc listall why] {
        set code "unknown"
        regexp {\(([^)]+)\)\s*$} $rule -> code
        set n [llength $coords]
        incr enumerated
        puts "VIOLATION rule=$code count=$n message=\"[normalize_message $rule]\""
    }

    if {$total > 0 && $enumerated == 0} {
        puts "DRC_FIND_BEGIN"
        drc find
        puts "DRC_FIND_END"
    }
} err]} {
    puts "ERROR rule=DRIVER message=\"[normalize_message $err]\""
    exit 1
}

puts "DRC_DONE"
quit -noprompt
