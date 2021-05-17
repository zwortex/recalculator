Red [
    Title:   "Test set for recalculator.red"
    Author: "Zwortex"
    File:    %recalculator-test.red
    License: {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes: { ... }
    Version: 0.1.0
    Date: 06/05/2021
    Changelog: {

        0.1.0 - 06/05/2021
            * initial version

    }
    Tabs:    4
]

; Need recalculator - otherwise nothing to work on !
; before unset all to make sure everthing is reloaded
unset 'recalculator-test
unset 'recalculator
; set recalculator-test however to prevent running the calculator in test mode
; see #if at the end of %recalculator.red
recalculator-test: context [] 
#include %recalculator.red

; A context for holding the test cases
recalculator-test: context [

    ; run all the test
    run: function [] [
        print "Run all tests"
        test-stack
        test-tree
        test-lexer
        test-spacer
        test-syntaxer
        test-computation
        test-model
        test-presenter
        ;recalculator/run ; interactive
        print "Done - Run all tests"
    ]

    ; Special assert for the sake of testing
    ; just runs a block of commands and compares the result to an expected value (strict equal)
    ; that's it but pretty useful in itself.
    assert: function [
            test [string!]
            check [block!]
            against [any-type!]
    ][
        check-value: do check
        cond: strict-equal? check-value against
        either cond [
            print [ "OK" test "- test:" mold/flat check "- got:" mold/flat check-value ]
        ][
            print [ "NOK" test "- test:" mold/flat check "- expecting:" mold/flat against "- got:" mold/flat check-value ]
        ]
    ]

    ; to probe an expression as it is being evaluated
    tee: function [
        val [any-type!]
        return: [any-type!]
    ][
        probe val
        return val
    ]

    ; select swap serie and value
    ss: function [ value [any-type!] series [series! any-object! map! none!] ][
        select series value
    ]

    ;; Testing the stack object used by the recalculator
    test-stack: function [] [
        print "Test-stack"
        p: []
        s: recalculator/stack/clone
        s/init
        assert "stack#1" [ s/is-empty ] true
        s/rule/enter 'r1 p
        assert "stack#2" [ all [ 'sep == s/top-1 'r1 == s/top ] ] true
        s/push 'a
        s/push 'b
        assert "stack#3" [ 'b == s/top ] true
        assert "stack#4" [ 'a == s/top-1 ] true
        s/rule/keep
        assert "stack#5" [ 'b == s/top ] true
        s/rule/enter 'r2 p
        s/push 'c
        s/push 15
        assert "stack#6" [ 15 == s/top ] true
        s/rule/fail
        assert "stack#7" [ 'b == s/top ] true
        s/rule/enter 'r3 p
        s/push 'd
        s/push 20
        s/rule/enter 'r4 p
        s/push 'e
        s/push 35
        s/rule/keep
        s/rule/fail
        assert "stack#8" [ not s/is-empty ] true
        s/init
        s/rule/enter 'r1 p
        s/push "s1"
        s/push 2
        s/push/many [ "s3" "s4" ]
        s/push [ "b5" ]
        s/push make object! [ x: "o6" ] true
        s/rule/enter 'r2 p
        s/push "s7"
        s/rule/keep
        s/rule/keep
        assert "stack#9" [ s/mymold ] {["s1" 2 "s3" "s4" ["b5"] make object! [^/    x: "o6"^/] "s7"]}
        s/init
        s/push ["b1" "b2" "b3"]
        s/push/many ["b4" "b5" "b6"]
        assert "stack#10" [ s/mymold ] {[["b1" "b2" "b3"] "b4" "b5" "b6"]}
        print "Test-stack done"
    ]

    ;; Testing tree
    test-tree: function [] [
        print "Test-tree"
        a: make object! [ x: 1 ]
        t: recalculator/tree
        n00: t/create 'n00
        n01: t/create/with 'n01 1
        n02: t/create/with 'n02 2
        n03: t/create/with 'n03 3
        n04: t/create/with 'n04 4
        n05: t/create/with 'n05 5
        n06: t/create/with 'n06 6
        n11: t/create/with/unary 'n11 11 n01
        n12: t/create/with/unary 'n12 12 n02
        n13: t/create/with/unary 'n13 13 n03
        n21: t/create/with/binary 'n21 21 n04 n11
        n22: t/create/with/binary 'n22 22 n12 n05
        n23: t/create/with/binary 'n23 23 n21 n22
        attempt [ f1: none f1: t/create/unary 'f1 n01 ] ; fails as n01 in n11
        attempt [ f2: none f2: t/create/binary 'f2 n01 n06 ] ; idem
        attempt [ f3: none f3: t/create/binary 'f3 n06 n01 ] ; idem
        assert "tree#1" [
            not any [
                t/node? a
                t/leaf? n21
                t/unary? n01
                t/binary? n11
            ]
        ] true
        assert "tree#2" [
            all [
                t/node? n01
                t/leaf? n01
                t/unary? n11
                t/binary? n21
            ]
        ] true
        assert "tree#3" [
            all [
                0 == t/nb-children n01
                1 == t/nb-children n11
                2 == t/nb-children n21
            ]
        ] true
        assert "tree#4" [
            all [
                none == t/left n01
                n02 == t/left n12
                n12 == t/left n22
            ]
        ] true
        assert "tree#5" [
            all [
                none == t/right n01
                n01 == t/right n11
                n11 == t/right n21
            ]
        ] true
        assert "tree#6" [
            all [
                n01 == t/leftmost-leaf n01
                n02 == t/leftmost-leaf n12
                n02 == t/leftmost-leaf n22
            ]
        ] true
        assert "tree#7" [
            all [
                n01 == t/rightmost-leaf n01
                n01 == t/rightmost-leaf n11
                n01 == t/rightmost-leaf n21
            ]
        ] true
        assert "tree#8" [
            all [
                "n01:1" == t/as-string n01
                "n11:11" == t/as-string n11
                "n21:21" == t/as-string n21
            ]
        ] true
        assert "tree#9" [
            all [
                "[n01:1]" == t/mymold n01
                "[n11:11 [n01:1]]" == t/mymold n11
                "[n21:21 [n04:4] [n11:11 [n01:1]]]" == t/mymold n21
            ]
        ] true
        assert "tree#10" [
            all [
                "n01:1" == t/myform n01
                "n11:11(n01:1)" == t/myform n11
                "n04:4 n21:21 n11:11(n01:1)" == t/myform n21
            ]
        ] true
        assert "tree#11" [
            all [
                none? f1
                none? f2
                none? f3
            ]
        ] true
        n07: t/create/with 'n07 7
        n08: t/create/with 'n08 8
        n08: t/mutate/unary n08 n07
        assert "tree#12" [ t/mymold n08 ] "[n08:8 [n07:7]]"
        n09: t/create/with 'n09 9
        n08: t/mutate/binary n08 n07 n09
        assert "tree#13" [ t/mymold n08 ] "[n08:8 [n07:7] [n09:9]]"
        ;; search
        nvar1: t/create/with 'var 1
        nvar2: t/create/with 'var 2
        nvalue1: t/create/with 'value 1
        nvalue2: t/create/with 'value 2
        nadd1: t/create/binary 'add nvar1 nvalue1
        nadd2: t/create/binary 'add nvalue2 nvar2
        nmult1: t/create/binary 'multiply nadd1 nadd2
        nvar3: t/create/with 'var 3
        nsine: t/create/unary 'sine nvar3
        nmult2: t/create/binary 'multiply nsine nmult1
        ;; search for variables
        res: t/search-variables nmult2
        assert "tree#14" [ 
            all [
                res/1 == nvar3
                res/2 == nvar1
                res/3 == nvar2
            ]
         ] true
        print "Test-tree done"
    ]

    ;; Testing lexer functions
    test-lexer: function [] [
        print "Test-lexer"
        model: recalculator/model-core
        lexer: recalculator/lexer

        ; keys as string
        assert "keys-as-string#1" [ model/keys-as-string ['n1 'n2 'sine-r] ] "12[sinᵣ]"
        assert "keys-as-string#2" [ model/keys-as-string ['ets-spacer 'ets-spacer] ] "(←⦆₂"
        assert "keys-as-string#3" [ model/keys-as-string ['efs-spacer] ] "(→⦆"

        ; tokenize a stream of keys
        assert "lexer-on-keys#1" [ ss 'tokens lexer/run ['n1 'n2] ] [ ['value 1 3 12] ]
        assert "lexer-on-keys#2" [ ss 'tokens lexer/run ['n1 'n2 'decimal-separator 'n3 ] ] [ ['value 1 5 12.3] ]
        assert "lexer-on-keys#3" [ ss 'tokens lexer/run ['sine-r 'power-2] ] [ ['unary 1 2 'sine-r] ['unary 2 3 'power-2] ]
        assert "lexer-on-keys#4" [ ss 'tokens lexer/run ['add 'multiply 'power] ] [ ['binary 1 2 'add] ['binary 2 3 'multiply] ['binary 3 4 'power] ]
        assert "lexer-on-keys#5" [ ss 'tokens lexer/run ['paren-l 'paren-r ] ] [ ['paren 1 2 'paren-l] ['paren 2 3 'paren-r] ]
        assert "lexer-on-keys#6" [ ss 'tokens lexer/run ['E] ] [ [ 'constant 1 2  'E] ]
        assert "lexer-on-keys#7" [ ss 'tokens lexer/run ['ets-spacer] ] [ [ 'spacer 1 2 'ets-spacer 1 ] ]
        assert "lexer-on-keys#8" [ ss 'tokens lexer/run ['ets-spacer 'ets-spacer] ] [ [ 'spacer 1 3 'ets-spacer 2 ] ]
        assert "lexer-on-keys#9" [ ss 'tokens lexer/run ['var 'n3 'n5] ] [ [ 'var 1 4 35 ] ]
        assert "lexer-on-keys#10" [ ss 'tokens lexer/run ['add 'mult 'power] ] [ ['binary 1 2 'add] ]
        assert "lexer-on-keys#11" [ ss 'failed lexer/run ['add 'mult 'power] ] ['mult 'power]
        assert "lexer-on-keys#12" [ ss 'tokens lexer/run "𝑒" ] [ ['constant 1 2 'E] ]

        ; tokenize a string
        assert "lexer-on-str#1" [ ss 'tokens lexer/run "123456789" ] [ ['value 1 10 123456789] ]
        assert "lexer-on-str#2" [ ss 'tokens lexer/run "1234,56789" ] [ ['value 1 11 1234.56789] ]
        assert "lexer-on-str#3" [ ss 'tokens lexer/run "1,3456E78" ] [ ['value 1 10 1.3456E78] ]
        assert "lexer-on-str#4" [ ss 'tokens lexer/run "123,54e-89" ] [ ['value 1 11 1.2354e-87] ]
        assert "lexer-on-str#5" [ ss 'tokens lexer/run "²√-⁻¹" ] [ ['unary 1 2 'power-2] ['unary 2 3 'square-2] ['unary 3 4 'negate] ['unary 4 6 'inverse] ]
        assert "lexer-on-str#6" [ ss 'tokens lexer/run "+−×÷↑" ] [ ['binary 1 2 'add] ['binary 2 3 'subtract] ['binary 3 4 'multiply] ['binary 4 5 'divide] ['binary 5 6 'power] ]
        assert "lexer-on-str#7" [ ss 'tokens lexer/run "()" ] [ ['paren 1 2 'paren-l] ['paren 2 3 'paren-r] ]
        assert "lexer-on-str#8" [ ss 'tokens lexer/run "2+3×3⁻¹" ] [ ['value 1 2 2] ['binary 2 3 'add] ['value 3 4 3] ['binary 4 5 'multiply] ['value 5 6 3] ['unary 6 8 'inverse] ]
        assert "lexer-on-str#9" [ ss 'tokens lexer/run "2/3" ] [ ['value 1 2 2] ]
        assert "lexer-on-str#10" [ ss 'failed lexer/run "2/3" ] "/3"
        assert "lexer-on-str#11" [ ss 'tokens lexer/run "[1]" ] [ ['unary 1 2 'round] ['paren 2 2 'paren-l] ['value 2 3 1] ['paren 3 3 'paren-r] ]
        assert "lexer-on-str#12" [ ss 'tokens lexer/run "|1|" ] [ ['paren 1 2 'absolute?] ['value 2 3 1] ['paren 3 4 'absolute?] ]
        assert "lexer-on-str#13" [ ss 'tokens lexer/run "sinₕsinᵣ⁻¹log₂" ] [ ['unary 1 5 'sinh] ['unary 5 11 'sine-1-r] ['unary 11 15 'log-2] ]

        ; tokens as string
        assert "tokens-as-string#1" [ model/expr-tokens-as-string lexer/run "123456789" ] "123456789"
        assert "tokens-as-string#2" [ model/expr-tokens-as-string lexer/run "1234,56789" ] "1234.56789"
        assert "tokens-as-string#3" [ model/expr-tokens-as-string lexer/run "1,3456E78" ] "1.3456e78"
        assert "tokens-as-string#4" [ model/expr-tokens-as-string lexer/run "1,2354e-14" ] "1.2354e-14"
        assert "tokens-as-string#5" [ model/expr-tokens-as-string lexer/run "²√-⁻¹" ] "⁽²⁾[√][-]⁽⁻¹⁾"
        assert "tokens-as-string#6" [ model/expr-tokens-as-string lexer/run "+−×÷↑" ] "+−×÷↑"
        assert "tokens-as-string#7" [ model/expr-tokens-as-string lexer/run "()" ] "()"
        assert "tokens-as-string#8" [ model/expr-tokens-as-string lexer/run "2+3×3⁻¹" ] "2+3×3⁽⁻¹⁾"
        assert "tokens-as-string#9" [ model/expr-tokens-as-string lexer/run "#10" ] "#10"
        assert "tokens-as-string#10" [ model/expr-tokens-as-string lexer/run "[1]" ] "[x](1)"
        assert "tokens-as-string#11" [ model/expr-tokens-as-string lexer/run "|1|" ] "[absolute?]1[absolute?]"
        assert "tokens-as-string#12" [ model/expr-tokens-as-string lexer/run "sinₕsinᵣ⁻¹log₂log₁₀csc₉csc₉⁻¹" ] "[sinₕ][sinᵣ⁻¹][log₂][log₁₀][csc₉][csc₉⁻¹]"
        assert "tokens-as-string#13" [ model/expr-tokens-as-string lexer/run "logₑ35⦅→)₁+√10(←⦆" ] "[logₑ]35⦅→)₁+[√]10(←⦆₁"
        assert "tokens-as-string#14" [ model/expr-tokens-as-string lexer/run "logₑ35+√10(←⦆₂" ] "[logₑ]35+[√]10(←⦆₂"
        assert "tokens-as-string#15" [ model/expr-tokens-as-string lexer/run "-10mod5÷11rem5" ] "[-]10mod5÷11rem5"

        ; debug
        assert "lexer-debug#1" [ model/expr-tokens-as-string lexer/run "√4+4(4−2²)+5×sin₀(5)++45−5" ] "[√]4+4(4−2⁽²⁾)+5×[sin₀](5)++45−5"

        print "Test-lexer done"
    ]

    ;; Testing spacer
    test-spacer: function [] [
        print "Test-spacer"
        lexer: recalculator/lexer
        spacer: recalculator/spacer
        model: recalculator/model-core

        ; 'ets-spacer (←⦆
        assert "spacer_ets-spacer#1" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆" ] "1×2+3+4×5×(6)"
        assert "spacer_ets-spacer#2" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆₂" ] "1×2+3+4×(5×6)"
        assert "spacer_ets-spacer#3" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆₃" ] "1×2+3+(4×5×6)"
        assert "spacer_ets-spacer#4" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆₄" ] "1×2+(3+4×5×6)"
        assert "spacer_ets-spacer#5" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆₅" ] "1×(2+3+4×5×6)"
        assert "spacer_ets-spacer#6" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆₆" ] "(1×2+3+4×5×6)"
        assert "spacer_ets-spacer#7" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3+4×5×6(←⦆₇" ] "(1×2+3+4×5×6)"
        
        assert "spacer_ets-spacer#8" [ model/expr-tokens-as-string spacer/run lexer/run "(1+2+3(←⦆)" ] "(1+2+(3))"
        assert "spacer_ets-spacer#9" [ model/expr-tokens-as-string spacer/run lexer/run "(1+2+3(←⦆₂)" ] "(1+(2+3))"
        assert "spacer_ets-spacer#10" [ model/expr-tokens-as-string spacer/run lexer/run "(1+2+3(←⦆₃)" ] "((1+2+3))"

        assert "spacer_ets-spacer#11" [ model/expr-tokens-as-string spacer/run lexer/run "0+1+(2+3)+4(←⦆"] "0+1+(2+3)+(4)"
        assert "spacer_ets-spacer#12" [ model/expr-tokens-as-string spacer/run lexer/run "0+1+(2+3)+4(←⦆₂"] "0+1+((2+3)+4)"
        assert "spacer_ets-spacer#13" [ model/expr-tokens-as-string spacer/run lexer/run "0+1+(2+3)+4(←⦆₃"] "0+(1+(2+3)+4)"
        assert "spacer_ets-spacer#14" [ model/expr-tokens-as-string spacer/run lexer/run "0+1+(2+3)+4(←⦆₄"] "(0+1+(2+3)+4)"
        assert "spacer_ets-spacer#15" [ model/expr-tokens-as-string spacer/run lexer/run "0+1+(2+3(←⦆)+4(←⦆₃"] "0+(1+(2+(3))+4)"

        assert "spacer_ets-spacer#16" [ model/expr-tokens-as-string spacer/run lexer/run "logₑ35+√10(←⦆" ] "[logₑ]35+[√](10)"
        assert "spacer_ets-spacer#17" [ model/expr-tokens-as-string spacer/run lexer/run "logₑ35+√10(←⦆₂" ] "[logₑ]35+([√]10)"
        assert "spacer_ets-spacer#18" [ model/expr-tokens-as-string spacer/run lexer/run "logₑ35+√10(←⦆₃" ] "[logₑ](35+[√]10)"
        assert "spacer_ets-spacer#19" [ model/expr-tokens-as-string spacer/run lexer/run "logₑ35+√10(←⦆₄" ] "([logₑ]35+[√]10)"

        ; 'efs-spacer (→⦆
        assert "spacer_efs-spacer#1" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3(→⦆" ] "(1×2+3)"
        assert "spacer_efs-spacer#2" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3(→⦆₂" ] "1×(2+3)"
        assert "spacer_efs-spacer#3" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3(→⦆₃" ] "1×2+(3)"
        assert "spacer_efs-spacer#4" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3(→⦆₄" ] "1×2+(3)"

        ; 'ste-spacer ⦅→)
        assert "spacer_ste-spacer#1" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅→)" ] "(1)×2+3"
        assert "spacer_ste-spacer#2" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅→)₂" ] "(1×2)+3"
        assert "spacer_ste-spacer#3" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅→)₃" ] "(1×2+3)"
        assert "spacer_ste-spacer#4" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅→)₄" ] "(1×2+3)"

        ; 'sfe-spacer ⦅←)
        assert "spacer_sfe-spacer#1" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅←)" ] "(1×2+3)"
        assert "spacer_sfe-spacer#2" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅←)₂" ] "(1×2)+3"
        assert "spacer_sfe-spacer#3" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅←)₃" ] "(1)×2+3"
        assert "spacer_sfe-spacer#4" [ model/expr-tokens-as-string spacer/run lexer/run "1×2+3⦅←)₄" ] "(1)×2+3"

        ; insides
        assert "spacer_insides#1" [ model/expr-tokens-as-string spacer/run lexer/run "1+2⦅←)+2" ] "(1+2)+2"
        assert "spacer_insides#2" [ model/expr-tokens-as-string spacer/run lexer/run "1+2×3⦅←)₂+4⦅←)×5" ] "((1+2)×3+4)×5"
        assert "spacer_insides#3" [ model/expr-tokens-as-string spacer/run lexer/run "logₑπ+2(←⦆₂" ] "[logₑ](π+2)"
        
        ; failed lexer, failed syntax
        assert "spacer_failed#1" [ model/expr-tokens-as-string spacer/run lexer/run "1+2⦅←)+" ] "(1+2)" ; discarded after
        assert "spacer_failed#2" [ model/expr-tokens-as-string spacer/run lexer/run "1+2⦅←)*2" ] "(1+2)" ; failed after
        assert "spacer_failed#3" [ model/expr-tokens-as-string spacer/run lexer/run "1*2⦅←)+2" ] "1" ; failed before
        assert "spacer_failed#4" [ model/expr-tokens-as-string spacer/run lexer/run "(←⦆" ] "" ; fully discarded

        ; absolute
        assert "spacer_absolute#1" [ model/expr-tokens-as-string spacer/run lexer/run "|1|" ] "|x|(1)"
        assert "spacer_absolute#2" [ model/expr-tokens-as-string spacer/run lexer/run "|1+2|" ] "|x|(1+2)"
        assert "spacer_absolute#3" [ model/expr-tokens-as-string spacer/run lexer/run "|1+(2+3)|" ] "|x|(1+(2+3))"
        assert "spacer_absolute#4" [ model/expr-tokens-as-string spacer/run lexer/run "|5|+|1+2+3)|" ] "|x|(5)"
        assert "spacer_absolute#5" [ model/expr-tokens-as-string spacer/run lexer/run "|5|+|1+(2+3|" ] "|x|(5)"

        print "Test-spacers done"
    ]

    ;; Testing syntaxer
    test-syntaxer: function [] [
        print "Test-syntaxer"
        lexer: recalculator/lexer
        spacer: recalculator/spacer
        syntaxer: recalculator/syntaxer
        model: recalculator/model-core

        ; syntax rules
        assert "syntaxer_0" [ model/expr-node-as-string syntaxer/run lexer/run "1" ] "1"
        assert "syntaxer_1" [ model/expr-node-as-string syntaxer/run lexer/run "1×2" ] "1 × 2"
        assert "syntaxer_1" [ model/expr-node-as-string syntaxer/run lexer/run "1×2+3×4" ] "1 × 2 + 3 × 4"
        assert "syntaxer_2" [ model/expr-node-as-string syntaxer/run lexer/run "(1×2)+(3×4)" ] "(1 × 2) + (3 × 4)"
        assert "syntaxer_3" [ model/expr-node-as-string syntaxer/run lexer/run "1×(2+3)×4" ] "1 × (2 + 3) × 4"
        assert "syntaxer_4" [ model/expr-node-as-string syntaxer/run lexer/run "(1×2+3)×4" ] "(1 × 2 + 3) × 4"
        assert "syntaxer_5" [ model/expr-node-as-string syntaxer/run lexer/run "1×(2+3×4)" ] "1 × (2 + 3 × 4)"
        assert "syntaxer_6" [ model/expr-node-as-string syntaxer/run lexer/run "1+2×3+4" ] "1 + 2 × 3 + 4"
        assert "syntaxer_7" [ model/expr-node-as-string syntaxer/run lexer/run "1+2+3+4" ] "1 + 2 + 3 + 4"
        assert "syntaxer_8" [ model/expr-node-as-string syntaxer/run lexer/run "sinᵣ1" ] "sinᵣ1"
        assert "syntaxer_9" [ model/expr-node-as-string syntaxer/run lexer/run "sinᵣ1+2" ] "sinᵣ1 + 2"
        assert "syntaxer_10" [ model/expr-node-as-string syntaxer/run lexer/run "sinᵣ(1+2)" ] "sinᵣ(1 + 2)"
        assert "syntaxer_11" [ model/expr-node-as-string syntaxer/run lexer/run "1sinᵣ√" ] "√(sinᵣ1)"
        assert "syntaxer_12" [ model/expr-node-as-string syntaxer/run lexer/run "3↑4+5×6" ] "3 ↑ 4 + 5 × 6"
        assert "syntaxer_13" [ model/expr-node-as-string syntaxer/run lexer/run "3↑(4+5)×6" ] "3 ↑ (4 + 5) × 6"
        assert "syntaxer_14" [ model/expr-node-as-string syntaxer/run lexer/run "3↑4↑5×6+7" ] "3 ↑ 4 ↑ 5 × 6 + 7"
        assert "syntaxer_15" [ model/expr-node-as-string syntaxer/run lexer/run "(2+3)(3×5)" ] "(2 + 3) ⋅ (3 × 5)"
        assert "syntaxer_16" [ model/expr-node-as-string syntaxer/run lexer/run "2(3+4)×5" ] "2 ⋅ (3 + 4) × 5"
        assert "syntaxer_17" [ model/expr-node-as-string syntaxer/run lexer/run "2×(3+4)5" ] "2 × (3 + 4) ⋅ 5"
        assert "syntaxer_18" [ model/expr-node-as-string syntaxer/run lexer/run "2(𝑒+1)+3π÷3" ] "2 ⋅ (𝑒 + 1) + 3 ⋅ π ÷ 3"
        assert "syntaxer_19" [ model/expr-node-as-string syntaxer/run lexer/run "#2sinᵣ" ] "sinᵣ(#2)"
        assert "syntaxer_20" [ model/expr-node-as-string syntaxer/run lexer/run "sinᵣ#2" ] "sinᵣ(#2)"
        assert "syntaxer_21" [ model/expr-node-as-string syntaxer/run lexer/run "-1mod2+3rem4" ] "-1 mod 2 + 3 rem 4"
        assert "syntaxer_22" [ model/expr-node-as-string syntaxer/run lexer/run "𝑒" ] "𝑒"
        assert "syntaxer_23" [ model/expr-node-as-string syntaxer/run lexer/run "1" ] "1"
        assert "syntaxer_24" [ model/expr-node-as-string syntaxer/run lexer/run "(1+2)" ] "(1 + 2)"
        assert "syntaxer_25" [ model/expr-node-as-string syntaxer/run lexer/run "10%+2!" ] "10% + 2!"

        ; lex /syntaxer failure
        assert "syntaxer_fails_1" [ model/expr-failed-as-string syntaxer/run lexer/run "√" ] "√"
        assert "syntaxer_fails_2" [ model/expr-failed-as-string syntaxer/run lexer/run "√+" ] "√+"
        assert "syntaxer_fails_3" [ model/expr-failed-as-string syntaxer/run lexer/run "√3*5" ] "*5"
        assert "syntaxer_fails_4" [ model/expr-failed-as-string syntaxer/run lexer/run "√3+4(3××5)" ] "(3××5)"
        assert "syntaxer_fails_5" [ model/expr-failed-as-string syntaxer/run lexer/run "√3+4(3×5)" ] ""
        assert "syntaxer_fails_6" [ model/expr-failed-as-string syntaxer/run lexer/run "1++" ] "++"

        ; failure with spacer
        assert "syntaxer_fails_7" [ model/expr-failed-as-string syntaxer/run spacer/run lexer/run "1+2⦅←)+" ] "+"
        assert "syntaxer_fails_8" [ model/expr-failed-as-string syntaxer/run spacer/run lexer/run "1+2⦅←)*2" ] "*2"
        assert "syntaxer_fails_9" [ model/expr-failed-as-string syntaxer/run spacer/run lexer/run "1*2⦅←)+2" ] "*2⦅←)+2"
        assert "syntaxer_fails_10" [ model/expr-failed-as-string syntaxer/run spacer/run lexer/run "1++2(←⦆+2+" ] "++2(←⦆+2+"
        assert "syntaxer_fails_11" [ model/expr-failed-as-string syntaxer/run spacer/run lexer/run "1+1⦅←)++2(←⦆+2+" ] "++2(←⦆+2+"

        ; debug
        assert "syntaxer_debug_1" [ 
            c: syntaxer/run spacer/run lexer/run "√4+4(4−2²)+5×sin₀(5)++45−5"
            (model/expr-node-as-string c) == "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(5)"
            (model/expr-failed-as-string c) ==  "++45−5"
        ] true
        assert "syntaxer_debug_2" [
            c: syntaxer/run spacer/run lexer/run ""
            all [
                c/source-as-string == ""
                none? c/node
            ]
        ] true
        print "Test-syntaxer done"
    ]

    ;; Computation
    test-computation: function [] [
        print "Test-computation"
        lexer: recalculator/lexer
        spacer: recalculator/spacer
        syntaxer: recalculator/syntaxer
        tree: recalculator/tree
        model: recalculator/model

        ; conversion to string
        values: [
            2.7182818284590452353602874713527 "2.718281828459045"
            3.1415926535897932384626433832795 "3.141592653589793"
            0.49999999999999994 "0.5"
            30.000000000000004 "30"
            30000 "30 000"
            3.0 "3"
            3.3333333333333335 "3.333333333333334"
            33.333333333333336 "33.33333333333334"
            30.000000000000004 "30"
            70.0E45 "7.0e46"
            10.0E-5 "0.0001"
            1.0E-16 "0" ; limit
            1.#NaN "Invalid"
            1.#INF "Positive Overflow"
            -1.#INF "Negative Overflow"
            0.0 "0"
            -0.0 "0"
            10000000000.0 "10 000 000 000"
            (cosine 90) "0"
        ]

        forall values [
            assert 
                rejoin [ "conversion_" ( (index? values) + 1 / 2) ] 
                compose [ recalculator/funcs/form (values/1) ] 
                values/2
            values: next values
        ]

        values: [

            ; constants
            "𝑒" 2,7182818284590452353602874713527
            "π" 3,1415926535897932384626433832795

            ; binary operations
            "1+2" 3
            "10−5" 5
            "-10−20" -30
            "1+2×3" 7
            "(1+2)3" 9
            "2↑3" 8
            "2↑3↑4" 4096
            "2↑3×4" 32
            "2↑-3" 0.125
            "10÷3" 3,3333333333333333333333333333333
            "21mod4" 1
            "21rem4" 1
            "-21mod5" 4
            "-21rem5" -1
            "2E-3" 0,002
            "2E2" 200
            "5↑/3" 1.7099759466766968 ; 1,7099759466766969893531088725439

            ; unary rounding ops
            ;"|5|" 5
            ;"|-5|" 5
            "[0,7]" 1
            "[0,3]" 0
            "⎡0,7⎤" 1
            "⎡0,3⎤" 1
            "⎣0,7⎦" 0
            "⎣0,3⎦" 0

            ; unary ops
            "5!" 120
            "12!" 479'001'600
            "13!" 6'227'020'800.0
            "-5" -5
            "5⁻¹" 0,2
            "5%" 0,05

            ; unary power
            "2²" 4
            "√2" 1,4142135623730950488016887242097
            "2³" 8
            "³√2" 1,2599210498948731647672106072782

            ; trigonometric functions in radian
            "sinᵣ2" 0,90929742682568169539601986591174
            "cosᵣ2" -0,41614683654714238699756822950076
            "tanᵣ2" -2,1850398632615189916433061023137
            "sinᵣ⁻¹0,5" 0,52359877559829887307710723054658
            "cosᵣ⁻¹0,5" 1.0471975511965976 ; 1,0471975511965977461542144610932
            "tanᵣ⁻¹0,5" 0,46364760900080611621425623146121
            "cscᵣ2" 1,0997501702946164667566973970263
            "secᵣ2" -2,4029979617223809897546004014201
            "cotᵣ2" -0,45765755436028576375027741043205
            "cscᵣ⁻¹2" 0,52359877559829887307710723054658
            "secᵣ⁻¹2" 1.0471975511965976
                     ;1,0471975511965977461542144610932
            "cotᵣ⁻¹2" 0,46364760900080611621425623146121

            ; trigonometric functions in degree
            "sin₀20" 0,34202014332566873304409961468226
            "sin₀⁻¹0,5" 30.000000000000004 ;30

            ; trigonometric functions in gradient
            "sin₉20"  0.3090169943749474
                     ;0,30901699437494742410229341718282
            "sin₉⁻¹0,5" 33,333333333333333333333333333333

            ; hyperbolic functions
            "sinₕ2" 3.6268604078470187676682139828013
            "cosₕ2" 3.762195691083631
                   ;3,7621956910836314595622134777737
            "tanₕ2" 0.964027580075817
                   ;0,96402758007581688394641372410092
            "sinₕ⁻¹2" 1,4436354751788103424932767402731
            "cosₕ⁻¹2" 1.3169578969248166 
                     ;1,316957896924816708625046347308
            "tanₕ⁻¹0,5" 0,54930614433405484569762261846126
            "cscₕ2" 0.27572056477178325 ; ??
                   ;0,27572056477178320775835148216303
            "secₕ2" 0.2658022288340797
                   ;0,26580222883407969212086273981989
            "cotₕ2" 1.037314720727548
                   ;1,0373147207275480958778097647678
            "cscₕ⁻¹2" 0,48121182505960344749775891342437
            "secₕ⁻¹0,5" 1.3169578969248166 ; ??
                       ;1,316957896924816708625046347308
            "cotₕ⁻¹2" 0,54930614433405484569762261846126

            ; log/exp functions
            "log₂2" 1
            "logₑ2" 0.69314718055994530941723212145818
            "log₁₀2" 0.30102999566398119521373889472449
            "2↑15" 32768
            "𝑒↑5" 148.41315910257657 ; ??
                 ;148.41315910257660342111558004055
            "10↑3" 1000

            ; specials
            "200!" 1.#INF
            "-(200!)" -1.#INF
            "10÷0" 1.#NaN
            "toto" #[none] ; no value computed as unknown operation

        ]
        forall values [
            assert 
                rejoin [ "computation_" ( (index? values) + 1 / 2) ] 
                compose [ recalculator/funcs/form model/expr-value model/expr-new/compute (values/1) ] 
                recalculator/funcs/form values/2
            values: next values
        ]
        print "Test-computation done"
    ]

; test-model variables and stack
    test-model: function [] [

        print "Test-model"
        model: recalculator/model
        tree: recalculator/tree

        ; expr initialisation
        n1: model/expr-new "√4+3↑2"
        assert "model_expr#1_1" [ n1/debug-string ] "[ √4+3↑2 ]"
        n2: model/expr-new "√4+3↑2"
        n3: model/expr-new "√4+3↑3"
        n4: n3/clone
        assert "model_expr#1_2" [
            all [
                n2/equals n1
                not n2/equals n3
                n4/equals n3
            ]
        ] true
        ; expr add/removal keys
        n1/remove-keys 2 ; 
        n2/remove-all-keys
        n3/add-keys "−1"
        assert "model_expr#2_1" [ n1/debug-string ] "[ √4+3 ]"
        assert "model_expr#2_2" [ n2/debug-string ] ""
        assert "model_expr#2_3" [ n3/debug-string ] "[ √4+3↑3−1 ]"
        ; expr simple computations
        n1: model/expr-new "1+2"
        n1/compute
        assert "model_expr#3_1" [ n1/value ] 3
        n2: model/expr-new "2×3"
        n2/compute
        assert "model_expr#3_2" [ n2/value ] 6
        n3: model/expr-new "2÷(5−5)"
        n3/compute
        assert "model_expr#3_3" [ to-string n3/value ] "1.#NaN" ; string comparaison as 1.#NaN == 1.#NaN alway false
        ; expr various strings
        n1: model/expr-new "√4+4(4−2²)+5×sin₀(30)++45−5"
        n1/compute
        assert "model_expr#4_1" [ n1/as-string ] "√4+4(4−2²)+5×sin₀(30)++45−5"
        assert "model_expr#4_2" [ n1/node-as-string ] "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(30)"
        assert "model_expr#4_3" [ n1/source-as-string ] "√4+4(4−2²)+5×sin₀(30)++45−5"
        assert "model_expr#4_4" [ n1/failed-as-string ] "++45−5"
        assert "model_expr#4_5" [ n1/tokens-as-string ] "[√]4+4(4−2⁽²⁾)+5×[sin₀](30)"
        assert "model_expr#4_7" [ n1/value-as-string ] "4.5"
        assert "model_expr#4_8" [ n1/debug-string ] "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(30) [ ++45−5 ] = 4.5"

        ; the same with tokens
        n1: model/expr-new [
            'square-2 'n4 'add 'n4 'paren-l 'n4 'subtract 'n2 'power-2 'paren-r
            'add 'n5 'multiply 'sine-d 'paren-l 'n3 'n0 'paren-r 
            'add 'add 'n4 'n5 'subtract 'n5
        ]
        n1/compute
        assert "model_expr#5_1" [ n1/debug-string ] "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(30) [ ++45−5 ] = 4.5"
        assert "model_expr#5_2" [ n1/tokens-as-string ] "[√]4+4(4−2⁽²⁾)+5×[sin₀](30)"
        ; expr clear, clear-failed, discard-tokens
        n1: model/expr-new "1+2×3−8÷4++6"
        assert "model_expr#6_1" [ n1/debug-string ] "[ 1+2×3−8÷4++6 ]"
        n1/compute
        assert "model_expr#6_2" [ n1/debug-string ] "1 + 2 × 3 − 8 ÷ 4 [ ++6 ] = 5"
        n2: n1/clone
        n3: n1/clone
        n4: n1/clone
        n2/clear
        assert "model_expr#6_3" [ n2/debug-string ] ""
        n3/clear-failed ; 1+2×3−8÷4
        assert "model_expr#6_4" [ n3/debug-string ] "1 + 2 × 3 − 8 ÷ 4 = 5"
        ; exprs clear, few adds and bits
        model/exprs-clear
        n1: model/expr-new "1+3"
        n1/compute
        model/exprs-add n1
        n2: model/expr-new "2×4"
        model/exprs-add n2
        n3: model/expr-new "3!"
        model/exprs-add/where n3 1
        n4: model/expr-new "4"
        model/exprs-add/where n4 5 ; expecting n3 n1 n2 n4
        assert "model_exprs#1" [ model/exprs-nb ] 4
        assert "model_exprs#2" [ model/exprs-debug-string ] {1: [3! = 6]
2: [1 + 3 = 4]
3: [2 × 4 = 8]
4: [4 = 4]}
        assert "model_exprs#3" [ model/expr-equals (model/exprs-get 1) n3 ] true
        assert "model_exprs#4" [ none? model/exprs-get 5 ] true
        assert "model_exprs#5" [ model/exprs-gets == reduce [ n3 n1 n2 n4 ] ] true
        ; few modifications
        nr2: model/exprs-remove 3 ; now n3 n1 n4 - removing n2
        assert "model_exprs#6" [ model/expr-equals nr2 n2 ] true
        nm2: model/exprs-modify 2 n2 ; now n3 n2 n4
        assert "model_exprs#7" [ model/expr-equals nm2 n2 ] true
        nm2: attempt [ model/exprs-add nm2 ]; attempt to put back the same
        assert "model_exprs#8" [ none? nm2 ] true
        assert "model_exprs#9" [ model/exprs-debug-string ] {1: [3! = 6]
2: [2 × 4 = 8]
3: [4 = 4]}
        ; create new expression with references to the stack
        model/exprs-clear
        n1: model/expr-new "1+3"
        model/exprs-add n1
        n2: model/expr-new "2×4"
        model/exprs-add n2
        n3: model/expr-new "#1+#2"
        n3/compute
        assert "model_var#1" [ n3/debug-string ] "#1[ 1 + 3 ] + #2[ 2 × 4 ] = 12"
        ; create multiple references to an expression in the stack
        model/exprs-clear
        n1: model/expr-new "2+2"
        model/exprs-add n1
        n2: model/expr-new "(2+2×#1)×2"
        model/exprs-add n2
        n3: model/expr-new "√#1"
        model/exprs-add n3
        model/exprs-recompute
        assert "model_var#2" [ model/exprs-debug-string ] {1: [2 + 2 = 4]
2: [(2 + 2 × #1[ 2 + 2 ]) × 2 = 20]
3: [√(#1[ 2 + 2 ]) = 2]}
        ; create references to a missing expression
        model/exprs-clear
        n1: model/expr-new "2+2"
        model/exprs-add n1
        n2: model/expr-new "#3"
        model/exprs-add n2
        model/exprs-recompute
        assert "model_var#3" [ model/exprs-debug-string ] {1: [2 + 2 = 4]
2: [[ #3 ]]}
        ; error if self reference
        model/exprs-clear
        n1: model/expr-new "#1"
        model/exprs-add/where n1 1
        n1/compute
        assert "model_var#4" [ n1/debug-string ] "[ #1 ]"
        ; create multi-depth references
        n1: model/expr-new "2+2"
        n2: model/expr-new "2+3×#1"
        n3: model/expr-new "√#1"
        n4: model/expr-new "3×#2"
        n5: model/expr-new "#4+#3+#2+#1"
        model/exprs-restore [ n1 n2 n3 n4 n5 ]
        assert "model_var#5" [ model/exprs-debug-string ] {1: [2 + 2 = 4]
2: [2 + 3 × #1[ 2 + 2 ] = 14]
3: [√(#1[ 2 + 2 ]) = 2]
4: [3 × #2[ 2 + 3 × #1[ 2 + 2 ] ] = 42]
5: [#4[ 3 × #2[ 2 + 3 × #1[ 2 + 2 ] ] ] + #3[ √(#1[ 2 + 2 ]) ] + #2[ 2 + 3 × #1[ 2 + 2 ] ] + #1[ 2 + 2 ] = 62]}
        ; create expressions with a cycle of dependencies
        n1: model/expr-new "2×#2"
        n2: model/expr-new "3+#3"
        n3: model/expr-new "5-#1"
        model/exprs-restore [ n1 n2 n3 ]
        assert "model_var#6" [ model/exprs-debug-string ] {1: [[ 2×#2 ]]
2: [[ 3+#3 ]]
3: [[ 5-#1 ]]}
        ; breaks the cycle
        n2/remove-keys 1 ; enougth to prevent +#3 being lexed
        model/exprs-recompute ; recompute all 
        assert "model_var#7" [ model/exprs-debug-string ] {1: [2 × #2[ 3 ] = 6]
2: [3 [ +# ] = 3]
3: [-5 ⋅ #1[ 2 × #2[ 3 ] ] = -30]}
        ; discard an expression and put it back
        model/exprs-clear
        n1: model/expr-new "1+4"
        n2: model/expr-new "1+5"
        n3: model/expr-new "#2−#1"
        model/exprs-restore [ n1 n2 n3 ]
        assert "model_var#8_1" [ model/exprs-debug-string ] {1: [1 + 4 = 5]
2: [1 + 5 = 6]
3: [#2[ 1 + 5 ] − #1[ 1 + 4 ] = 1]}
        nr: model/exprs-remove 1 ; ex n1
        assert "model_var#8_2" [ model/exprs-debug-string ] {1: [1 + 5 = 6]
2: [[ #2−#1 ]]}
        model/exprs-add nr ; even if put back on top
        assert "model_var#8_3" [ model/exprs-debug-string ] {1: [1 + 5 = 6]
2: [[ #2−#1 ]]
3: [1 + 4 = 5]}

        print "Test-model - done"

    ]

    test-presenter: function [] [
        print "Test-presenter"
        presenter: recalculator/presenter
        model: recalculator/model
        presenter/reset

        assert "presenter_key-label" [ presenter/key-label 'add ] "+"
        assert "presenter_key-label" [ presenter/key-label 'sine-r ] "sinᵣ"
        assert "presenter_key-label" [ presenter/key-label 'power ] "𝑥ʸ"
        assert "presenter_key-label" [ presenter/key-label 'nope ] "?"
        assert "presenter_angle" [
            all [
                presenter/angle == 'radian
                (presenter/degree presenter/angle) == 'degree
                (presenter/gradient presenter/angle) == 'gradient
                (presenter/radian presenter/angle) == 'radian
            ]
        ] true

        ; key1
        presenter/reset
        presenter/push-key 'n1
        presenter/push-key 'add
        presenter/push-key 'n2
        assert "presenter_key1#1" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/push-key 'add
        assert "presenter_key1#2" [ presenter/expr-debug-string ] "1 + 2 [ + ] = 3"
                                                                  "1 + 2 [ + ]  = 3"
        presenter/back-space
        assert "presenter_key1#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/push-key 'clear-expr
        assert "presenter_key1#4" [ presenter/expr-debug-string ] ""

        ; key2
        presenter/reset
        presenter/push-key 'n1
        presenter/push-key 'add
        presenter/push-key 'n2
        presenter/push-key 'paren-r
        presenter/push-key 'n3
        presenter/push-key 'add
        presenter/push-key 'n4
        presenter/push-key 'paren-r
        assert "presenter_key2#1" [ presenter/expr-debug-string ] "1 + 2 [ )3+4) ] = 3"
        presenter/back-space
        presenter/back-space
        presenter/back-space
        presenter/back-space
        presenter/back-space
        assert "presenter_key2#2" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/push-key 'add
        presenter/push-key 'n4
        assert "presenter_key2#3" [ presenter/expr-debug-string ] "1 + 2 + 4 = 7"

        ; key3
        presenter/reset
        presenter/push-key 'n1
        presenter/push-key 'add
        presenter/push-key 'n2
        presenter/clear-expr
        presenter/push-key 'n3
        presenter/push-key 'multiply
        presenter/push-key 'n4
        assert "presenter_key3#1" [ presenter/expr-debug-string ] "3 × 4 = 12"
        presenter/clear-expr
        assert "presenter_key3#2" [ presenter/expr-debug-string ] ""
        presenter/clear-expr
        assert "presenter_key3#3" [ presenter/expr-debug-string ] ""

        ; enter1
        presenter/reset
        presenter/push-key 'n1
        presenter/push-key 'add
        presenter/push-key 'n2
        presenter/enter
        assert "presenter_enter1#1" [ presenter/expr-debug-string ] ""
        assert "presenter_enter1#2" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
        presenter/enter
        assert "presenter_enter1#3" [ presenter/expr-debug-string ] ""
        assert "presenter_enter1#4" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
        presenter/push-key 'n3
        presenter/enter
        assert "presenter_enter1#5" [ presenter/expr-debug-string ] ""
        assert "presenter_enter1#6" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3 = 3" ]
        presenter/push-key 'n4
        presenter/push-key 'add
        assert "presenter_enter1#7" [ presenter/expr-debug-string ] "4 [ + ] = 4"
        assert "presenter_enter1#8" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3 = 3" ]
        presenter/enter
        assert "presenter_enter1#9" [ presenter/expr-debug-string ] "[ + ]"
        assert "presenter_enter1#10" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3 = 3" "4 = 4" ]

        ; enter2
        presenter/reset
        presenter/push-key 'n4
        presenter/push-key 'add
        presenter/push-key 'n5
        presenter/enter
        assert "presenter_enter2#1" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" ]
        presenter/push-key 'n4
        presenter/push-key 'square-2
        presenter/enter
        assert "presenter_enter2#2" [ presenter/expr-stack-debug ] [ "4 + 5 = 9"  "√4 = 2" ]

        ; enter3 / sel-expr/ pull-expr
        presenter/reset
        presenter/push-key 'n1
        presenter/push-key 'add
        presenter/push-key 'n2
        presenter/push-key 'add
        presenter/enter
        assert "presenter_enter3#1" [ presenter/expr-debug-string ] "[ + ]"
        assert "presenter_enter3#2" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
        presenter/back-space
        presenter/push-key 'n3
        presenter/push-key 'factorial
        presenter/enter
        assert "presenter_enter3#3" [ presenter/expr-debug-string ] ""
        assert "presenter_enter3#4" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3! = 6" ]
        assert "presenter_enter3#5" [
            all [ 
                do [ presenter/sel-expr 1 presenter/expr-index == 1 ]
                do [ presenter/sel-expr 0 presenter/expr-index == 0 ]
                do [ presenter/sel-expr 3 presenter/expr-index == 0 ]
            ]
        ] true
        presenter/sel-expr 1
        presenter/pull-expr
        assert "presenter_enter3#6" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/sel-expr 2
        presenter/pull-expr
        assert "presenter_enter3#7" [ presenter/expr-debug-string ] "3! = 6"
        presenter/push-key 'add
        presenter/push-key 'n4
        assert "presenter_enter3#8" [ presenter/expr-debug-string ] "3! + 4 = 10"
        assert "presenter_enter3#9" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3! = 6" ]
        presenter/enter
        assert "presenter_enter3#10" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3! + 4 = 10" ]
        presenter/sel-expr 1
        presenter/pull-expr
        assert "presenter_enter3#11" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/sel-expr 0
        presenter/pull-expr
        assert "presenter_enter3#12" [ presenter/expr-debug-string ] ""
        presenter/sel-expr 1
        presenter/pull-expr
        assert "presenter_enter3#13" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/sel-expr 3
        presenter/pull-expr
        assert "presenter_enter3#14" [ presenter/expr-debug-string ] ""

        ; pull-expr / clear-expr
        presenter/reset
        presenter/key-entry 'n1
        presenter/key-entry 'add
        presenter/key-entry 'n2
        presenter/enter
        presenter/push-key 'n4
        presenter/push-key 'add
        presenter/push-key 'n5
        presenter/enter
        assert "presenter_pull-expr1#1" [ presenter/expr-debug-string ] ""
        assert "presenter_pull-expr1#2" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
        presenter/sel-expr 1
        presenter/pull-expr
        assert "presenter_pull-expr1#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_pull-expr1#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
        presenter/clear-expr
        assert "presenter_pull-expr1#5" [ presenter/expr-debug-string ] ""
        assert "presenter_pull-expr1#6" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
        presenter/sel-expr 1
        presenter/pull-expr
        presenter/back-space
        assert "presenter_pull-expr1#7" [ presenter/expr-debug-string ] "4 [ + ] = 4"
        presenter/clear-expr
        assert "presenter_pull-expr1#8" [ presenter/expr-debug-string ] ""
        assert "presenter_pull-expr1#9" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]

        ; pull-expr / clear-expr with undo
        presenter/reset
        presenter/key-entry 'n1
        presenter/key-entry 'add
        presenter/key-entry 'n2
        presenter/enter
        presenter/push-key 'n4
        presenter/push-key 'add
        presenter/push-key 'n5
        presenter/enter
        presenter/sel-expr 1
        presenter/pull-expr
        presenter/clear-expr
        assert "presenter_pull-expr2#1" [ presenter/expr-debug-string ] ""
        assert "presenter_pull-expr2#2" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
        presenter/undo ; clear-expr buffer & line
        assert "presenter_pull-expr2#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_pull-expr2#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
        presenter/redo ; clear-expr buffer & line
        assert "presenter_pull-expr2#5" [ presenter/expr-debug-string ] ""
        assert "presenter_pull-expr2#6" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
        presenter/sel-expr 1
        presenter/pull-expr
        presenter/back-space
        assert "presenter_pull-expr2#7" [ presenter/expr-debug-string ] "4 [ + ] = 4"
        presenter/clear-expr ; only buffer
        assert "presenter_pull-expr2#8" [ presenter/expr-debug-string ] ""
        assert "presenter_pull-expr2#9" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
        presenter/undo ; clear-expr - only buffer
        assert "presenter_pull-expr2#10" [ presenter/expr-debug-string ] "4 [ + ] = 4"
        assert "presenter_pull-expr2#11" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
        presenter/undo
        assert "presenter_pull-expr2#12" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]

        ; clear-all
        presenter/reset
        presenter/clear-all
        assert "presenter_clear-all#1" [ presenter/expr-debug-string ] ""
        assert "presenter_clear-all#2" [ presenter/expr-stack-debug ] []
        presenter/push-key 'n9
        presenter/push-key 'n0 
        presenter/push-key 'cosine-d
        assert "presenter_clear-all#3" [ presenter/expr-debug-string ] "cos₀90 = 0"
        assert "presenter_clear-all#4" [ presenter/expr-stack-debug ] []
        presenter/enter
        assert "presenter_clear-all#5" [ presenter/expr-debug-string ] ""
        assert "presenter_clear-all#6" [ presenter/expr-stack-debug ] [ "cos₀90 = 0" ]

        ; undo1 : key-entry
        presenter/reset
        presenter/key-entry 'n3
        presenter/key-entry 'n0
        presenter/key-entry 'sine-d
        presenter/key-entry 'add
        presenter/key-entry 'n1
        assert "presenter_undo1#1" [ presenter/expr-debug-string ] "sin₀30 + 1 = 1.5"
        presenter/undo ; n1
        assert "presenter_undo1#2" [ presenter/expr-debug-string ] "sin₀30 [ + ] = 0.5"
        presenter/undo ; add
        assert "presenter_undo1#3" [ presenter/expr-debug-string ] "sin₀30 = 0.5"
        presenter/redo ; add
        assert "presenter_undo1#4" [ presenter/expr-debug-string ] "sin₀30 [ + ] = 0.5"
        presenter/redo ; n1
        assert "presenter_undo1#5" [ presenter/expr-debug-string ] "sin₀30 + 1 = 1.5"
        presenter/redo ; nothing
        assert "presenter_undo1#6" [ presenter/expr-debug-string ] "sin₀30 + 1 = 1.5"
        presenter/key-entry 'n0
        assert "presenter_undo1#7" [ presenter/expr-debug-string ] "sin₀30 + 10 = 10.5"
        presenter/undo presenter/undo presenter/undo presenter/undo ; n0 n1 add sin-d
        assert "presenter_undo1#8" [ presenter/expr-debug-string ] "30 = 30"
        presenter/undo presenter/undo ; n0 n3
        assert "presenter_undo1#9" [ presenter/expr-debug-string ] ""
        presenter/undo ; nothing
        assert "presenter_undo1#10" [ presenter/expr-debug-string ] ""
        presenter/redo presenter/redo presenter/redo presenter/redo presenter/redo presenter/redo ; n3 n0 sine-d add n1 n0
        assert "presenter_undo1#11" [ presenter/expr-debug-string ] "sin₀30 + 10 = 10.5"
        presenter/redo ; nothing
        assert "presenter_undo1#12" [ presenter/expr-debug-string ] "sin₀30 + 10 = 10.5"

        ; undo2 : enter
        presenter/reset
        presenter/key-entry 'n1
        presenter/enter
        presenter/key-entry 'n2
        presenter/enter
        assert "presenter_undo2#1" [ presenter/expr-debug-string ] ""
        assert "presenter_undo2#2" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
        presenter/undo ; enter-2 - n2
        assert "presenter_undo2#3" [ presenter/expr-debug-string ] "2 = 2"
        assert "presenter_undo2#4" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
        presenter/undo ; enter-1 - n2
        assert "presenter_undo2#5" [ presenter/expr-debug-string ] ""
        assert "presenter_undo2#6" [ presenter/expr-stack-debug ] ["1 = 1"]
        presenter/undo ; enter-2 - n1
        assert "presenter_undo2#7" [ presenter/expr-debug-string ] "1 = 1"
        assert "presenter_undo2#8" [ presenter/expr-stack-debug ] ["1 = 1"]
        presenter/undo ; enter-1 - n1
        assert "presenter_undo2#9" [ presenter/expr-debug-string ] "" ; 1 = 1
        assert "presenter_undo2#10" [ presenter/expr-stack-debug ] [] ; 1 = 1
        presenter/undo ; nothing
        assert "presenter_undo2#11" [ presenter/expr-debug-string ] "" ; 1 = 1
        assert "presenter_undo2#12" [ presenter/expr-stack-debug ] []
        presenter/redo ; enter-1 - n1
        assert "presenter_undo2#13" [ presenter/expr-debug-string ] "1 = 1"
        assert "presenter_undo2#14" [ presenter/expr-stack-debug ] ["1 = 1"]
        presenter/redo ; enter-2 - n1
        assert "presenter_undo2#15" [ presenter/expr-debug-string ] ""
        assert "presenter_undo2#16" [ presenter/expr-stack-debug ] ["1 = 1"]
        presenter/redo ; enter-1 - n2
        assert "presenter_undo2#17" [ presenter/expr-debug-string ] "2 = 2"
        assert "presenter_undo2#18" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
        presenter/redo ; enter-2 - n2
        assert "presenter_undo2#19" [ presenter/expr-debug-string ] ""
        assert "presenter_undo2#20" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
        presenter/redo ; nothing
        assert "presenter_undo2#21" [ presenter/expr-debug-string ] ""
        assert "presenter_undo2#22" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
        presenter/undo ; enter-2 - n2
        assert "presenter_undo2#23" [ presenter/expr-debug-string ] "2 = 2"
        assert "presenter_undo2#24" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]

        ; undo3 : key-entry / back-space
        presenter/reset
        presenter/key-entry 'n1
        assert "presenter_undo3#1" [ presenter/expr-debug-string ] "1 = 1"
        presenter/back-space ; n1
        assert "presenter_undo3#2" [ presenter/expr-debug-string ] ""
        presenter/undo ; back-space
        assert "presenter_undo3#3" [ presenter/expr-debug-string ] "1 = 1"
        presenter/redo ; back-space
        assert "presenter_undo3#4" [ presenter/expr-debug-string ] ""
        presenter/key-entry 'n2
        assert "presenter_undo3#5" [ presenter/expr-debug-string ] "2 = 2"
        presenter/undo ; n2
        assert "presenter_undo3#6" [ presenter/expr-debug-string ] ""
        presenter/undo ; back-space
        assert "presenter_undo3#7" [ presenter/expr-debug-string ] "1 = 1"
        presenter/key-entry 'n3 ; kill previous undos
        assert "presenter_undo3#8" [ presenter/expr-debug-string ] "13 = 13"
        presenter/undo ; n3
        assert "presenter_undo3#9" [ presenter/expr-debug-string ] "1 = 1"
        presenter/undo ; n1
        assert "presenter_undo3#10" [ presenter/expr-debug-string ] ""
        presenter/redo ; n1
        assert "presenter_undo3#11" [ presenter/expr-debug-string ] "1 = 1"
        presenter/redo ; n3
        assert "presenter_undo3#12" [ presenter/expr-debug-string ] "13 = 13"
        presenter/redo ; nothing
        assert "presenter_undo3#13" [ presenter/expr-debug-string ] "13 = 13"

        ; undo7 : clear-expr
        presenter/reset
        presenter/key-entry 'n1
        presenter/key-entry 'add
        presenter/key-entry 'n2
        assert "presenter_undo7#1" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/clear-expr
        assert "presenter_undo7#2" [ presenter/expr-debug-string ] ""
        presenter/undo ; clear-expr
        assert "presenter_undo7#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/redo ; clear-expr
        assert "presenter_undo7#4" [ presenter/expr-debug-string ] ""
        presenter/undo ; clear-expr
        assert "presenter_undo7#5" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/key-entry 'n3
        assert "presenter_undo7#6" [ presenter/expr-debug-string ] "1 + 23 = 24"
        presenter/undo ; n3
        assert "presenter_undo7#7" [ presenter/expr-debug-string ] "1 + 2 = 3"
        presenter/undo ; n2
        assert "presenter_undo7#8" [ presenter/expr-debug-string ] "1 [ + ] = 1"

        ; undo5 : enter with failed characters
        presenter/reset
        presenter/key-entry 'n1
        presenter/key-entry 'add
        presenter/key-entry 'n2
        presenter/key-entry 'multiply
        assert "presenter_undo5#1" [ presenter/expr-debug-string ] "1 + 2 [ × ] = 3"
        assert "presenter_undo5#2" [ presenter/expr-stack-debug ] []
        presenter/enter
        assert "presenter_undo5#3" [ presenter/expr-debug-string ] "[ × ]"
        assert "presenter_undo5#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; enter
        assert "presenter_undo5#5" [ presenter/expr-debug-string ] ""
        assert "presenter_undo5#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/key-entry 'n3
        assert "presenter_undo5#7" [ presenter/expr-debug-string ] "3 = 3"
        assert "presenter_undo5#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; n3
        assert "presenter_undo5#9" [ presenter/expr-debug-string ] ""
        assert "presenter_undo5#10" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; enter-2
        assert "presenter_undo5#11" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo5#12" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; enter-1
        assert "presenter_undo5#13" [ presenter/expr-debug-string ] ""
        assert "presenter_undo5#14" [ presenter/expr-stack-debug ] []
        presenter/undo ; nothing
        assert "presenter_undo5#15" [ presenter/expr-debug-string ] ""
        assert "presenter_undo5#16" [ presenter/expr-stack-debug ] []
        presenter/redo ; enter-1
        assert "presenter_undo5#17" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo5#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/redo ; enter-2 === useful ?
        assert "presenter_undo5#17" [ presenter/expr-debug-string ] ""
        assert "presenter_undo5#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/redo ; n3
        assert "presenter_undo5#7" [ presenter/expr-debug-string ] "3 = 3"
        assert "presenter_undo5#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/redo ; nothing
        assert "presenter_undo5#7" [ presenter/expr-debug-string ] "3 = 3"
        assert "presenter_undo5#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]

        ; undo6 : clear-all
        presenter/reset
        presenter/key-entry 'n1
        presenter/key-entry 'add
        presenter/key-entry 'n2
        presenter/enter ; #1
        assert "presenter_undo6#1" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#2" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/key-entry 'n3
        presenter/key-entry 'n0
        presenter/key-entry 'sine-d
        assert "presenter_undo6#3" [ presenter/expr-debug-string ] "sin₀30 = 0.5"
        assert "presenter_undo6#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/enter ; #2
        assert "presenter_undo6#5" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
        presenter/clear-all
        assert "presenter_undo6#7" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#8" [ presenter/expr-stack-debug ] []
        presenter/undo ; clear-all
        assert "presenter_undo6#9" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#10" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
        presenter/redo ; clear-all
        assert "presenter_undo6#11" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#12" [ presenter/expr-stack-debug ] []
        presenter/key-entry 'n4
        presenter/key-entry 'factorial
        presenter/enter ; #3
        assert "presenter_undo6#13" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#14" [ presenter/expr-stack-debug ] ["4! = 24"]
        presenter/undo ; enter-2 #3
        assert "presenter_undo6#15" [ presenter/expr-debug-string ] "4! = 24"
        assert "presenter_undo6#16" [ presenter/expr-stack-debug ] ["4! = 24"]
        presenter/undo ; enter-1 #3
        assert "presenter_undo6#15" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#16" [ presenter/expr-stack-debug ] []
        presenter/undo ; clear-all
        assert "presenter_undo6#17" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
        presenter/undo ; enter-2 #2
        assert "presenter_undo6#19" [ presenter/expr-debug-string ] "sin₀30 = 0.5"
        assert "presenter_undo6#20" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
        presenter/undo ; enter-1 #2
        assert "presenter_undo6#21" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#22" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/key-entry 'n5
        presenter/enter ; #4
        presenter/key-entry 'n6
        presenter/key-entry 'add
        presenter/key-entry 'add
        assert "presenter_undo6#23" [ presenter/expr-debug-string ] "6 [ ++ ] = 6"
        assert "presenter_undo6#24" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
        presenter/clear-all
        assert "presenter_undo6#25" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#26" [ presenter/expr-stack-debug ] []
        presenter/undo ; clear-all
        assert "presenter_undo6#27" [ presenter/expr-debug-string ] "6 [ ++ ] = 6"
        assert "presenter_undo6#28" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
        presenter/key-entry 'n7
        assert "presenter_undo6#29" [ presenter/expr-debug-string ] "6 [ ++7 ] = 6"
        assert "presenter_undo6#30" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
        presenter/undo
        presenter/undo
        presenter/undo
        presenter/undo ; n7 + + 6
        assert "presenter_undo6#31" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#32" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
        presenter/undo ; enter-2 #4
        assert "presenter_undo6#33" [ presenter/expr-debug-string ] "5 = 5"
        assert "presenter_undo6#34" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
        presenter/undo ; enter-1 #4
        assert "presenter_undo6#35" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#36" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; enter-2 #1
        assert "presenter_undo6#37" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo6#38" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; enter-1 #1
        assert "presenter_undo6#39" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#40" [ presenter/expr-stack-debug ] []
        presenter/undo ; nothing
        assert "presenter_undo6#41" [ presenter/expr-debug-string ] ""
        assert "presenter_undo6#42" [ presenter/expr-stack-debug ] []

        ; undo7 : pull-expr
        presenter/reset
        presenter/push-key 'n1
        presenter/push-key 'add
        presenter/push-key 'n2
        presenter/enter ; #1
        presenter/push-key 'n3
        presenter/push-key 'subtract
        presenter/push-key 'n4
        presenter/enter ; #2

        assert "presenter_undo7#1" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#2" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/sel-expr 1 ; sel line 1
        presenter/pull-expr
        assert "presenter_undo7#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo7#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/push-key 'add
        presenter/push-key 'n4
        assert "presenter_undo7#5" [ presenter/expr-debug-string ] "1 + 2 + 4 = 7"
        assert "presenter_undo7#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/enter ; #3 - 1+2=3 => 1+2+4=7
        assert "presenter_undo7#7" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#8" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]
        presenter/undo ; #3 - enter 2 (clear)
        assert "presenter_undo7#9" [ presenter/expr-debug-string ] "1 + 2 + 4 = 7"
        assert "presenter_undo7#10" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]
        presenter/undo ; #3 - enter 1 - 1+2+4=7 => 1+2=3
        assert "presenter_undo7#11" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo7#12" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/undo ; pull-expr
        assert "presenter_undo7#13" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#14" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/undo ; #2 - 2
        assert "presenter_undo7#15" [ presenter/expr-debug-string ] "3 − 4 = -1"
        assert "presenter_undo7#16" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/undo ; #2 - 1
        assert "presenter_undo7#17" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; #1 - 2
        assert "presenter_undo7#19" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo7#20" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; #1 - 1
        assert "presenter_undo7#21" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#22" [ presenter/expr-stack-debug ] []
        presenter/redo ; #1 - 1
        assert "presenter_undo7#23" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo7#24" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/undo ; #1 - 1
        assert "presenter_undo7#25" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#26" [ presenter/expr-stack-debug ] []
        presenter/redo presenter/redo ; #1
        assert "presenter_undo7#27" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#28" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
        presenter/redo presenter/redo ; #2
        assert "presenter_undo7#29" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#30" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/redo ; pull-expr
        assert "presenter_undo7#31" [ presenter/expr-debug-string ] "1 + 2 = 3"
        assert "presenter_undo7#32" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
        presenter/redo presenter/redo ; #3
        assert "presenter_undo7#33" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#34" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]
        presenter/redo ; nothing
        assert "presenter_undo7#35" [ presenter/expr-debug-string ] ""
        assert "presenter_undo7#36" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]

        print "Test-presenter done"
    ]

]
;recalculator-test
;]

; Use immediately as it's still hot
recalculator-test/run

