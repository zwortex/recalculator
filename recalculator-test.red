Red [
    Title:   "Test set for recalculator.red"
    Author: "Zwortex"
    File:    %recalculator-test.red
    License: {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes: { ... }
    Version: 0.2.0
    Date: 31/07/2021
    Changelog: {
        0.2.0 - 31/07/2021
            * added
                - additional tests in presenter for new stack features and change in selection handling
            * house keeping
                - lexer and syntaxer tests made dynamic
                - alignment with recalculator/0.2.0
        0.1.0 - 06/05/2021
            * initial version
    }
    Tabs:    4
]

; Need recalculator - otherwise nothing to work on !
; before unset all to make sure everthing is reloaded
unset 'recalculator
unset 'recalculator-test

; set recalculator-test however to prevent running the calculator in test mode
; see #if at the end of %recalculator.red
recalculator-test: true
#include %recalculator.red

; A context for holding the test cases
recalculator-test: context [

; run all the test
;comment [
run: function [] [
    print "Run all tests"

    test-stack
    test-tree
    test-lexer
    test-spacer
    test-syntaxer
    test-computation
    test-calc
    test-calc-stack
    test-presenter
    recalculator/run ; interactive

    print "Done - Run all tests"
]
;run
;]

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

;; Testing the stack object used by the recalculator
;comment [
test-stack: function [] [
    print "Test-stack"
    p: []
    s: make recalculator/stack []
    s/init
    assert "stack#1" [ s/is-empty? ] true
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
    assert "stack#8" [ not s/is-empty? ] true
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
;test-stack
;]

;; Testing tree
;comment [
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
;test-tree
;]

;; Testing lexer functions
;comment [
test-lexer: function [] [
    print "Test-lexer"
    calc: recalculator/calc-core
    expr: recalculator/calc-core/get-expr
    lexer: recalculator/lexer

    ; keys as string
    assert "keys-as-string#1" [ calc/key-buffer-as-string ['n1 'n2 'sine-r] ] "12[sinᵣ]"
    assert "keys-as-string#2" [ calc/key-buffer-as-string ['ets-spacer 'ets-spacer] ] "(←⦆₂"
    assert "keys-as-string#3" [ calc/key-buffer-as-string ['efs-spacer] ] "(→⦆"

    ; tokenize a stream of keys
    values: [
        ['n1 'n2 ] [ ['value 1 3 12] ]
        ['n1 'n2 'decimal-separator 'n3 ] [ ['value 1 5 12.3] ]
        ['sine-r 'power-2 ] [ ['unary 1 2 'sine-r] ['unary 2 3 'power-2] ]
        ['add 'multiply 'pow ] [ ['binary 1 2 'add] ['binary 2 3 'multiply] ['binary 3 4 'pow] ]
        ['paren-l 'paren-r ] [ ['paren 1 2 'paren-l] ['paren 2 3 'paren-r] ]
        ['E-VAL ] [ [ 'constant 1 2  'E-VAL] ]
        ['ets-spacer ] [ [ 'spacer 1 2 'ets-spacer 1 ] ]
        ['ets-spacer 'ets-spacer ] [ [ 'spacer 1 3 'ets-spacer 2 ] ]
        ['var 'n3 'n5 ] [ [ 'var 1 4 35 ] ]
        ['add 'mult 'pow ] [ ['binary 1 2 'add] ]
    ]
    forall values [
        ; assert see above performs a do (interpretation) on the command
        assert
            rejoin [ "lexer-on-keys#" ( (index? values) + 1 / 2) ]                      ; name
            compose/only [ calc/expr-init (values/1) lexer/run expr expr/tokens ]       ; command - compose/only as values/1 is a block
            values/2                                                                    ; expected result
        values: next values
    ]

    ; tokenize a string
    values: [
        "123456789" [ ['value 1 10 123456789] ]
        "1234.56789" [ ['value 1 11 1234.56789] ]
        "1.3456E78" [ ['value 1 10 1.3456E78] ]
        "123.54e-89" [ ['value 1 11 1.2354e-87] ]
        "²√-⁻¹" [ ['unary 1 2 'power-2] ['unary 2 3 'square-2] ['unary 3 4 'opposite] ['unary 4 6 'inverse] ]
        "+−×÷↑" [ ['binary 1 2 'add] ['binary 2 3 'subtract] ['binary 3 4 'multiply] ['binary 4 5 'divide] ['binary 5 6 'pow] ]
        "()" [ ['paren 1 2 'paren-l] ['paren 2 3 'paren-r] ]
        "2+3×3⁻¹" [ ['value 1 2 2] ['binary 2 3 'add] ['value 3 4 3] ['binary 4 5 'multiply] ['value 5 6 3] ['unary 6 8 'inverse] ]
        "2/3" [ ['value 1 2 2] ]
        "[1]" [ ['unary 1 2 'rounding] ['paren 2 2 'paren-l] ['value 2 3 1] ['paren 3 3 'paren-r] ]
        "|1|" [ ['paren 1 2 'abs?] ['value 2 3 1] ['paren 3 4 'abs?] ]
        "sinₕsinᵣ⁻¹log₂" [ ['unary 1 5 'sinh] ['unary 5 11 'sine-1-r] ['unary 11 15 'logarithm-2] ]
        "𝑒" [ ['constant 1 2 'E-VAL] ]
    ]
    forall values [
        assert 
            rejoin [ "lexer-on-str#" ( (index? values) + 1 / 2) ]                   ; name
            compose [ calc/expr-init (values/1) lexer/run expr expr/tokens ]        ; command
            values/2                                                                ; expected result
        values: next values
    ]

    ; tokenize a stream of keys failed
    assert "lexer-failed#1" [ calc/expr-init ['add 'mult 'power] lexer/run expr expr/failed ] ['mult 'power]
    assert "lexer-failed#2" [ calc/expr-init "2/3" lexer/run expr expr/failed ] "/3"

    ; tokens as string
    values: [
        "123456789" "123456789"
        "1234.56789" "1234.56789"
        "1.3456E78" "1.3456e78"
        "1.2354e-14" "1.2354e-14"
        "²√-⁻¹" "⁽²⁾[√][-]⁽⁻¹⁾"
        "+−×÷↑" "+−×÷↑"
        "()" "()"
        "2+3×3⁻¹" "2+3×3⁽⁻¹⁾"
        "#10" "#10"
        "[1]" "[x](1)"
        "|1|" "[abs?]1[abs?]"
        "sinₕsinᵣ⁻¹log₂log₁₀csc₉csc₉⁻¹" "[sinₕ][sinᵣ⁻¹][log₂][log₁₀][csc₉][csc₉⁻¹]"
        "logₑ35⦅→)₁+√10(←⦆" "[logₑ]35⦅→)₁+[√]10(←⦆₁"
        "logₑ35+√10(←⦆₂" "[logₑ]35+[√]10(←⦆₂"
        "-10mod5÷11rem5" "[-]10mod5÷11rem5"
    ]
    forall values [
        assert 
            rejoin [ "tokens-as-string#" ( (index? values) + 1 / 2 ) ]                                      ; name
            compose [ calc/expr-init (values/1) lexer/run expr calc/expr-tokens-as-string ]  ; command
            values/2                                                                                        ; expected result
        values: next values
    ]

    ; other
    assert "lexer-other#1" [ calc/expr-init "√4+4(4−2²)+5×sin₀(5)++45−5"
        lexer/run expr calc/expr-tokens-as-string ] "[√]4+4(4−2⁽²⁾)+5×[sin₀](5)++45−5"
    assert "lexer-other#2" [ calc/expr-init ['rand 'n4] lexer/run expr calc/expr-tokens-as-string ] "[rand]₁4"
    assert "lexer-other#3" [ calc/expr-init ['rand 'n4 'add 'n6] lexer/run expr calc/expr-tokens-as-string ] "[rand]₂4+6"
    assert "lexer-other#4" [ calc/expr-init "rand10" lexer/run expr calc/expr-tokens-as-string ] "[rand]₃10"
    assert "lexer-other#4" [ calc/expr-init "rand₁₀53" lexer/run expr calc/expr-tokens-as-string ] "[rand]₁₀53"
    assert "lexer-other#4" [ calc/expr-init "rand" lexer/run expr calc/expr-tokens-as-string ] "[rand]₄"

    print "Test-lexer done"
]
;test-lexer
;]

;; Testing spacer
;comment [
test-spacer: function [] [
    print "Test-spacer"
    lexer: recalculator/lexer
    spacer: recalculator/spacer
    calc: recalculator/calc-core
    expr: recalculator/calc-core/get-expr

    ; values name / command / expected result
    values: [
        ; 'ets-spacer (←⦆
        "spacer_ets-spacer#1" "1×2+3+4×5×6(←⦆" "1×2+3+4×5×(6)"
        "spacer_ets-spacer#2" "1×2+3+4×5×6(←⦆₂" "1×2+3+4×(5×6)"
        "spacer_ets-spacer#3" "1×2+3+4×5×6(←⦆₃" "1×2+3+(4×5×6)"
        "spacer_ets-spacer#4" "1×2+3+4×5×6(←⦆₄" "1×2+(3+4×5×6)"
        "spacer_ets-spacer#5" "1×2+3+4×5×6(←⦆₅" "1×(2+3+4×5×6)"
        "spacer_ets-spacer#6" "1×2+3+4×5×6(←⦆₆" "(1×2+3+4×5×6)"
        "spacer_ets-spacer#7" "1×2+3+4×5×6(←⦆₇" "(1×2+3+4×5×6)"

        "spacer_ets-spacer#8" "(1+2+3(←⦆)" "(1+2+(3))"
        "spacer_ets-spacer#9" "(1+2+3(←⦆₂)" "(1+(2+3))"
        "spacer_ets-spacer#10" "(1+2+3(←⦆₃)" "((1+2+3))"

        "spacer_ets-spacer#11" "0+1+(2+3)+4(←⦆" "0+1+(2+3)+(4)"
        "spacer_ets-spacer#12" "0+1+(2+3)+4(←⦆₂" "0+1+((2+3)+4)"
        "spacer_ets-spacer#13" "0+1+(2+3)+4(←⦆₃" "0+(1+(2+3)+4)"
        "spacer_ets-spacer#14" "0+1+(2+3)+4(←⦆₄" "(0+1+(2+3)+4)"
        "spacer_ets-spacer#15" "0+1+(2+3(←⦆)+4(←⦆₃" "0+(1+(2+(3))+4)"

        "spacer_ets-spacer#16" "logₑ35+√10(←⦆" "[logₑ]35+[√](10)"
        "spacer_ets-spacer#17" "logₑ35+√10(←⦆₂" "[logₑ]35+([√]10)"
        "spacer_ets-spacer#18" "logₑ35+√10(←⦆₃" "[logₑ](35+[√]10)"
        "spacer_ets-spacer#19" "logₑ35+√10(←⦆₄" "([logₑ]35+[√]10)"

        ; 'efs-spacer (→⦆
        "spacer_efs-spacer#1" "1×2+3(→⦆" "(1×2+3)"
        "spacer_efs-spacer#2" "1×2+3(→⦆₂" "1×(2+3)"
        "spacer_efs-spacer#3" "1×2+3(→⦆₃" "1×2+(3)"
        "spacer_efs-spacer#4" "1×2+3(→⦆₄" "1×2+(3)"

        ; 'ste-spacer ⦅→)
        "spacer_ste-spacer#1"  "1×2+3⦅→)" "(1)×2+3"
        "spacer_ste-spacer#2"  "1×2+3⦅→)₂" "(1×2)+3"
        "spacer_ste-spacer#3"  "1×2+3⦅→)₃" "(1×2+3)"
        "spacer_ste-spacer#4"  "1×2+3⦅→)₄" "(1×2+3)"

        ; 'sfe-spacer ⦅←)
        "spacer_sfe-spacer#1"  "1×2+3⦅←)" "(1×2+3)"
        "spacer_sfe-spacer#2"  "1×2+3⦅←)₂" "(1×2)+3"
        "spacer_sfe-spacer#3"  "1×2+3⦅←)₃" "(1)×2+3"
        "spacer_sfe-spacer#4"  "1×2+3⦅←)₄" "(1)×2+3"

        ; insides
        "spacer_insides#1"  "1+2⦅←)+2" "(1+2)+2"
        "spacer_insides#2"  "1+2×3⦅←)₂+4⦅←)×5" "((1+2)×3+4)×5"
        "spacer_insides#3"  "logₑπ+2(←⦆₂" "[logₑ](π+2)"

        ; failed lexer, failed syntax
        "spacer_failed#1"  "1+2⦅←)+" "(1+2)" ; discarded after
        "spacer_failed#2"  "1+2⦅←)*2" "(1+2)" ; failed after
        "spacer_failed#3"  "1*2⦅←)+2" "1" ; failed before
        "spacer_failed#4" "(←⦆" "" ; fully discarded

        ; absolute
        "spacer_absolute#1" "|1|" "|x|(1)"
        "spacer_absolute#2"  "|1+2|" "|x|(1+2)"
        "spacer_absolute#3"  "|1+(2+3)|" "|x|(1+(2+3))"
        "spacer_absolute#4"  "|5|+|1+2+3)|" "|x|(5)"
        "spacer_absolute#5" "|5|+|1+(2+3|" "|x|(5)"
    ]
    forall values [
        assert 
            values/1
            compose [ calc/expr-init (values/2) lexer/run expr spacer/run expr calc/expr-tokens-as-string ]
            values/3
        values: next next values
    ]

    print "Test-spacers done"
]
;test-spacer
;]

;; Testing syntaxer
;comment [
test-syntaxer: function [] [
    print "Test-syntaxer"
    lexer: recalculator/lexer
    spacer: recalculator/spacer
    syntaxer: recalculator/syntaxer
    calc: recalculator/calc-core
    expr: recalculator/calc-core/get-expr

    ; syntax rules
    ; values name / command / expected result
    values: [
        "syntaxer_0" "1" "1"
        "syntaxer_1" "1×2" "1 × 2"
        "syntaxer_1" "1×2+3×4" "1 × 2 + 3 × 4"
        "syntaxer_2" "(1×2)+(3×4)" "(1 × 2) + (3 × 4)"
        "syntaxer_3" "1×(2+3)×4" "1 × (2 + 3) × 4"
        "syntaxer_4" "(1×2+3)×4" "(1 × 2 + 3) × 4"
        "syntaxer_5" "1×(2+3×4)" "1 × (2 + 3 × 4)"
        "syntaxer_6" "1+2×3+4" "1 + 2 × 3 + 4"
        "syntaxer_7" "1+2+3+4" "1 + 2 + 3 + 4"
        "syntaxer_8" "sinᵣ1" "sinᵣ1"
        "syntaxer_9" "sinᵣ1+2" "sinᵣ1 + 2"
        "syntaxer_10" "sinᵣ(1+2)" "sinᵣ(1 + 2)"
        "syntaxer_11" "1sinᵣ√" "√(sinᵣ1)"
        "syntaxer_12" "3↑4+5×6" "3 ↑ 4 + 5 × 6"
        "syntaxer_13" "3↑(4+5)×6" "3 ↑ (4 + 5) × 6"
        "syntaxer_14" "3↑4↑5×6+7" "3 ↑ 4 ↑ 5 × 6 + 7"
        "syntaxer_15" "(2+3)(3×5)" "(2 + 3) ⋅ (3 × 5)"
        "syntaxer_16" "2(3+4)×5" "2 ⋅ (3 + 4) × 5"
        "syntaxer_17" "2×(3+4)5" "2 × (3 + 4) ⋅ 5"
        "syntaxer_18" "2(𝑒+1)+3π÷3" "2 ⋅ (𝑒 + 1) + 3 ⋅ π ÷ 3"
        "syntaxer_19" "#2sinᵣ" "sinᵣ(#2)"
        "syntaxer_20" "sinᵣ#2" "sinᵣ(#2)"
        "syntaxer_21" "-1mod2+3rem4" "-1 mod 2 + 3 rem 4"
        "syntaxer_22" "𝑒" "𝑒"
        "syntaxer_23" "1" "1"
        "syntaxer_24" "(1+2)" "(1 + 2)"
        "syntaxer_25" "10%+2!" "10% + 2!"
    ]
    forall values [
        assert 
            values/1
            compose [ calc/expr-init (values/2) syntaxer/run spacer/run lexer/run expr calc/expr-node-as-string ]
            values/3
        values: next next values
    ]

    values: [
        ; lex /syntaxer failure
        "syntaxer_fails_1" "√" "√"
        "syntaxer_fails_2" "√+" "√+"
        "syntaxer_fails_3" "√3*5" "*5"
        "syntaxer_fails_4" "√3+4(3××5)" "(3××5)"
        "syntaxer_fails_5" "√3+4(3×5)" ""
        "syntaxer_fails_6" "1++" "++"

        ; failure with spacer
        "syntaxer_fails_7" "1+2⦅←)+" "+"
        "syntaxer_fails_8" "1+2⦅←)*2" "*2"
        "syntaxer_fails_9" "1*2⦅←)+2" "*2⦅←)+2"
        "syntaxer_fails_10" "1++2(←⦆+2+" "++2(←⦆+2+"
        "syntaxer_fails_11" "1+1⦅←)++2(←⦆+2+" "++2(←⦆+2+"
    ]
    forall values [
        assert 
            values/1
            compose [ calc/expr-init (values/2) syntaxer/run spacer/run lexer/run expr calc/expr-failed-as-string ]
            values/3
        values: next next values
    ]

    ; debug
    assert "syntaxer_debug_1" [
        calc/expr-init "√4+4(4−2²)+5×sin₀(5)++45−5"
        syntaxer/run spacer/run lexer/run expr
        ( calc/expr-node-as-string ) == "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(5)"
        ( calc/expr-failed-as-string ) ==  "++45−5"
    ] true
    assert "syntaxer_debug_2" [
        calc/expr-init ""
        syntaxer/run spacer/run lexer/run expr
        all [
            ( calc/expr-source-as-string ) == ""
            none? expr/node
        ]
    ] true

    print "Test-syntaxer done"
]
;test-syntaxer
;]

;; Computation
;comment [
test-computation: function [] [
    print "Test-computation"
    funcs: recalculator/funcs
    tree: recalculator/tree
    calc: recalculator/calc

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
            compose [ funcs/format (values/1) ] 
            values/2
        values: next values
    ]

    ; computation
    values: [

        ; constants
        "𝑒" 2.7182818284590452353602874713527
        "π" 3.1415926535897932384626433832795

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
        "10÷3" 3.3333333333333333333333333333333
        "21mod4" 1
        "21rem4" 1
        "-21mod5" 4
        "-21rem5" -1
        "2E-3" 0.002
        "2E2" 200
        "5↑/3" 1.7099759466766968 ; 1.7099759466766969893531088725439

        ; unary rounding ops
        ;"|5|" 5
        ;"|-5|" 5
        "[0.7]" 1
        "[0.3]" 0
        "⎡0.7⎤" 1
        "⎡0.3⎤" 1
        "⎣0.7⎦" 0
        "⎣0.3⎦" 0

        ; unary ops
        "5!" 120
        "12!" 479'001'600
        "13!" 6'227'020'800.0
        "-5" -5
        "5⁻¹" 0.2
        "5%" 0.05

        ; unary power
        "2²" 4
        "√2" 1.4142135623730950488016887242097
        "2³" 8
        "³√2" 1.2599210498948731647672106072782

        ; trigonometric functions in radian
        "sinᵣ2" 0.90929742682568169539601986591174
        "cosᵣ2" -0.41614683654714238699756822950076
        "tanᵣ2" -2.1850398632615189916433061023137

        "sinᵣ⁻¹0.5" 0.52359877559829887307710723054658
        "cosᵣ⁻¹0.5" 1.0471975511965976 ; 1.0471975511965977461542144610932
        "tanᵣ⁻¹0.5" 0.46364760900080611621425623146121

        "cscᵣ2" 1.0997501702946164667566973970263
        "secᵣ2" -2.4029979617223809897546004014201
        "cotᵣ2" -0.45765755436028576375027741043205
        "cscᵣ⁻¹2" 0.52359877559829887307710723054658
        "secᵣ⁻¹2" 1.0471975511965976
                    ;1.0471975511965977461542144610932
        "cotᵣ⁻¹2" 0.46364760900080611621425623146121

        ; trigonometric functions in degree
        "sin₀20" 0.34202014332566873304409961468226

        "sin₀⁻¹0.5" 30.000000000000004 ;30

        ; trigonometric functions in gradient
        "sin₉20"  0.3090169943749474
                    ;0.30901699437494742410229341718282

        "sin₉⁻¹0.5" 33.333333333333333333333333333333

        ; hyperbolic functions
        "sinₕ2" 3.6268604078470187676682139828013
        "cosₕ2" 3.762195691083631
                ;3.7621956910836314595622134777737
        "tanₕ2" 0.964027580075817
                ;0.96402758007581688394641372410092
        "sinₕ⁻¹2" 1.4436354751788103424932767402731
        "cosₕ⁻¹2" 1.3169578969248166 
                    ;1.316957896924816708625046347308

        "tanₕ⁻¹0.5" 0.54930614433405484569762261846126

        "cscₕ2" 0.27572056477178325 ; ??
                ;0.27572056477178320775835148216303
        "secₕ2" 0.2658022288340797
                ;0.26580222883407969212086273981989
        "cotₕ2" 1.037314720727548
                ;1.0373147207275480958778097647678
        "cscₕ⁻¹2" 0.48121182505960344749775891342437
        "secₕ⁻¹0.5" 1.3169578969248166 ; ??
                    ;1.316957896924816708625046347308
        "cotₕ⁻¹2" 0.54930614433405484569762261846126

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
        "0!" 1
        "3E.5" 1.#NaN

    ]
    forall values [
        assert 
            rejoin [ "computation_" ( (index? values) + 1 / 2) ] 
            compose [
                calc/expr-init (values/1)
                calc/expr-compute
                funcs/format calc/expr-value
            ]
            funcs/format (values/2)
        values: next values
    ]

    ;; Random computation
    assert "computation_special#1" [ 
        calc/expr-init "rand50"
        calc/expr-compute
        v: calc/expr-value
        calc/expr-compute
        w: calc/expr-value
        v = w 
    ] true

    print "Test-computation done"
]
;test-computation
;]

; test-calc variables and stack
;comment [
test-calc: function [] [

    print "Test-calc"
    tree: recalculator/tree
    calc: recalculator/calc
    expr: recalculator/expr

    ; create void objets for the compiler to know what it is manipulating
    n1: make expr []
    n2: make expr []
    n3: make expr []
    n4: make expr []
    n5: make expr []
    n6: make expr []

    ; expr initialisation
    calc/expr-clear/with n1
    calc/expr-init/with "√4+3↑2" n1
    assert "model_expr#1_1" [ calc/expr-debug-string/with n1 ] "[ √4+3↑2 ]"

    calc/expr-init/with "√4+3↑2" n2
    calc/expr-init/with "√4+3↑3" n3
    calc/expr-init/with n3 n4
    assert "model_expr#1_2" [
        all [
            calc/expr-equals/with n1 n2 
            not calc/expr-equals/with n3 n2 
            calc/expr-equals/with n3 n4
        ]
    ] true

    ; expr add/removal keys
    calc/expr-remove-keys/with 2 n1
    calc/expr-remove-all-keys/with n2
    calc/expr-add-keys/with "−1" n3
    assert "model_expr#2_1" [ calc/expr-debug-string/with n1 ] "[ √4+3 ]"
    assert "model_expr#2_2" [ calc/expr-debug-string/with n2 ] ""
    assert "model_expr#2_3" [ calc/expr-debug-string/with n3 ] "[ √4+3↑3−1 ]"
    ; expr simple computations
    calc/expr-init/compute/with "1+2" n1
    assert "model_expr#3_1" [ calc/expr-value/with n1 ] 3
    calc/expr-init/compute/with "2×3" n2
    assert "model_expr#3_2" [ calc/expr-value/with n2 ] 6
    calc/expr-init/compute/with "2÷(5−5)" n3
    assert "model_expr#3_3" [ to-string calc/expr-value/with n3 ] "1.#NaN" ; string comparaison as 1.#NaN == 1.#NaN alway false
    ; expr various strings
    calc/expr-init/compute/with "√4+4(4−2²)+5×sin₀(30)++45−5" n1
    assert "model_expr#4_1" [ calc/expr-source-as-string/with n1 ] "√4+4(4−2²)+5×sin₀(30)++45−5"
    assert "model_expr#4_2" [ calc/expr-node-as-string/with n1 ] "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(30)"
    assert "model_expr#4_3" [ calc/expr-failed-as-string/with n1 ] "++45−5"
    assert "model_expr#4_4" [ calc/expr-tokens-as-string/with n1 ] "[√]4+4(4−2⁽²⁾)+5×[sin₀](30)"
    assert "model_expr#4_5" [ calc/expr-value-as-string/with n1 ] "4.5"
    assert "model_expr#4_6" [ calc/expr-debug-string/with n1 ] "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(30) [ ++45−5 ] = 4.5"

    ; the same with tokens
    calc/expr-init/compute/with [
        'square-2 'n4 'add 'n4 'paren-l 'n4 'subtract 'n2 'power-2 'paren-r
        'add 'n5 'multiply 'sine-d 'paren-l 'n3 'n0 'paren-r 
        'add 'add 'n4 'n5 'subtract 'n5
    ] n1
    assert "model_expr#5_1" [ calc/expr-debug-string/with n1 ] "√4 + 4 ⋅ (4 − 2²) + 5 × sin₀(30) [ ++45−5 ] = 4.5"
    assert "model_expr#5_2" [ calc/expr-tokens-as-string/with n1 ] "[√]4+4(4−2⁽²⁾)+5×[sin₀](30)"
    ; expr clear, clear-failed
    calc/expr-init/with "1+2×3−8÷4++6" n1
    assert "model_expr#6_1" [ calc/expr-debug-string/with n1 ] "[ 1+2×3−8÷4++6 ]"
    calc/expr-compute/with n1
    assert "model_expr#6_2" [ calc/expr-debug-string/with n1 ] "1 + 2 × 3 − 8 ÷ 4 [ ++6 ] = 5"
    calc/expr-init/with n1 n2
    calc/expr-init/with n1 n3
    calc/expr-init/with n1 n4
    calc/expr-clear/with n2
    assert "model_expr#6_3" [ calc/expr-debug-string/with n2 ] ""
    calc/expr-clear-failed/with n3 ; 1+2×3−8÷4
    assert "model_expr#6_4" [ calc/expr-debug-string/with n3 ] "1 + 2 × 3 − 8 ÷ 4 = 5"
    print "Test-calc - done"

]
;test-calc
;]

; test-model variables and stack
;comment [
test-calc-stack: function [] [
    print "Test-calc-stack"
    funcs: recalculator/funcs
    tree: recalculator/tree
    calc: recalculator/calc
    expr: recalculator/expr

    ; create void objets for the compiler to know what it is manipulating
    n1: make expr []
    n2: make expr []
    n3: make expr []
    n4: make expr []
    n5: make expr []
    n6: make expr []

    ; exprs clear, few adds and bits
    calc/exprs-clear
    calc/expr-init/compute/with "1+3" n1
    calc/exprs-add n1
    calc/expr-init/with "2×4" n2
    calc/exprs-add n2
    calc/expr-init/with "3!" n3
    calc/exprs-add/where n3 1
    calc/expr-init/with "4" n4
    calc/exprs-add/where n4 5 ; expecting n3 n1 n2 n4
    assert "model_exprs#1" [ calc/exprs-nb ] 4
    assert "model_exprs#2" [ calc/exprs-debug-string ] 
{1: [3! = 6]
2: [1 + 3 = 4]
3: [2 × 4 = 8]
4: [4 = 4]}
    assert "model_exprs#3" [ calc/expr-equals/with (calc/exprs-get 1) n3 ] true
    assert "model_exprs#4" [ none? calc/exprs-get 5 ] true
    assert "model_exprs#5" [ calc/exprs-gets == reduce [ n3 n1 n2 n4 ] ] true
    ; few modifications
    ; anytime a value is returned, looks a do block is mandatory
    nr2: do [ calc/exprs-remove 3 ] ; now n3 n1 n4 - removing n2
    assert "model_exprs#6" [ calc/expr-equals/with nr2 n2 ] true ; the same with equals but as it is in assert, there is a do block there
    nm2: do [ calc/exprs-modify 2 n2 ] ; now n3 n2 n4
    assert "model_exprs#7" [ calc/expr-equals/with n2 nm2 ] true
    nm2: attempt [ calc/exprs-add nm2 ]; attempt to put back the same
    assert "model_exprs#8" [ none? nm2 ] true
    assert "model_exprs#9" [ calc/exprs-debug-string ] {1: [3! = 6]
2: [2 × 4 = 8]
3: [4 = 4]}
    ; create new expression with references to the stack
    calc/exprs-clear
    calc/expr-init/with "1+3" n1
    calc/exprs-add n1
    calc/expr-init/with "2×4" n2
    calc/exprs-add n2
    calc/expr-init/with "#1+#2" n3
    calc/expr-compute/with n3
    assert "model_var#1" [ calc/expr-debug-string/with n3 ] "#1[ 1 + 3 ] + #2[ 2 × 4 ] = 12"
    ; create multiple references to an expression in the stack
    calc/exprs-clear
    calc/expr-init/with "2+2" n1
    calc/exprs-add n1
    calc/expr-init/with "(2+2×#1)×2" n2
    calc/exprs-add n2
    calc/expr-init/with "√#1" n3
    calc/exprs-add n3
    calc/exprs-recompute
    assert "model_var#2" [ calc/exprs-debug-string ]
{1: [2 + 2 = 4]
2: [(2 + 2 × #1[ 2 + 2 ]) × 2 = 20]
3: [√(#1[ 2 + 2 ]) = 2]}
    ; create references to a missing expression
    calc/exprs-clear
    calc/expr-init/with "2+2" n1
    calc/exprs-add n1
    calc/expr-init/with "#3" n2
    calc/exprs-add n2
    calc/exprs-recompute
    assert "model_var#3" [ calc/exprs-debug-string ]
{1: [2 + 2 = 4]
2: [[ #3 ]]}
    ; error if self reference
    calc/exprs-clear
    calc/expr-init/with "#1" n1
    calc/exprs-add/where n1 1
    calc/expr-compute/with n1
    assert "model_var#4" [ calc/expr-debug-string/with n1 ] "[ #1 ]"
    ; create multi-depth references
    calc/exprs-clear
    calc/expr-init/with "2+2" n1
    calc/expr-init/with "2+3×#1" n2
    calc/expr-init/with "√#1" n3
    calc/expr-init/with "3×#2" n4
    calc/expr-init/with "#4+#3+#2+#1" n5
    calc/exprs-restore [ n1 n2 n3 n4 n5 ]
    assert "model_var#5" [ calc/exprs-debug-string ]
{1: [2 + 2 = 4]
2: [2 + 3 × #1[ 2 + 2 ] = 14]
3: [√(#1[ 2 + 2 ]) = 2]
4: [3 × #2[ 2 + 3 × #1[ 2 + 2 ] ] = 42]
5: [#4[ 3 × #2[ 2 + 3 × #1[ 2 + 2 ] ] ] + #3[ √(#1[ 2 + 2 ]) ] + #2[ 2 + 3 × #1[ 2 + 2 ] ] + #1[ 2 + 2 ] = 62]}
    ; create expressions with a cycle of dependencies
    calc/expr-init/with "2×#2" n1
    calc/expr-init/with "3+#3" n2
    calc/expr-init/with "5-#1" n3
    calc/exprs-restore [ n1 n2 n3 ]
    assert "model_var#6" [ calc/exprs-debug-string ] {1: [[ 2×#2 ]]
2: [[ 3+#3 ]]
3: [[ 5-#1 ]]}
    ; breaks the cycle
    calc/expr-remove-keys/with 1 n2 ; enougth to prevent +#3 being lexed
    calc/exprs-recompute ; recompute all 
    assert "model_var#7" [ calc/exprs-debug-string ]
{1: [2 × #2[ 3 ] = 6]
2: [3 [ +# ] = 3]
3: [-5 ⋅ #1[ 2 × #2[ 3 ] ] = -30]}
    ; discard an expression and put it back
    calc/exprs-clear
    calc/expr-init/with "1+4" n1
    calc/expr-init/with "1+5" n2
    calc/expr-init/with "#2−#1" n3
    calc/exprs-restore [ n1 n2 n3 ]
    assert "model_var#8_1" [ calc/exprs-debug-string ]
{1: [1 + 4 = 5]
2: [1 + 5 = 6]
3: [#2[ 1 + 5 ] − #1[ 1 + 4 ] = 1]}
    nr: do [ calc/exprs-remove 1 ] ; ex n1
    assert "model_var#8_2" [ calc/exprs-debug-string ]
{1: [1 + 5 = 6]
2: [[ #2−#1 ]]}
    calc/exprs-add nr ; even if put back on top
    assert "model_var#8_3" [ calc/exprs-debug-string ]
{1: [1 + 5 = 6]
2: [[ #2−#1 ]]
3: [1 + 4 = 5]}

    print "Test-calc-stack - done"
]
;test-calc-stack
;]

;comment [
test-presenter: function [] [
    print "Test-presenter"
    presenter: recalculator/presenter
    calc: recalculator/calc

    ; label
    presenter/reset
    assert "presenter_label" [ presenter/key-label 'add ] "+"
    assert "presenter_label" [ presenter/key-label 'sine-r ] "sinᵣ"
    assert "presenter_label" [ presenter/key-label 'pow ] "𝑥ʸ"
    assert "presenter_label" [ presenter/key-label 'nope ] "?"
    assert "presenter_angle" [
        all [
            presenter/angle == 'radian
            (presenter/degree presenter/angle) == 'degree
            (presenter/gradient presenter/angle) == 'gradient
            (presenter/radian presenter/angle) == 'radian
        ]
    ] true

    ; key1: push-key with key or control (backspace)
    presenter/reset
    assert "presenter_key1#1" [ presenter/expr-debug-string ] ""
    presenter/push-key 'n1
    assert "presenter_key1#2" [ presenter/expr-debug-string ] "1 = 1"
    presenter/undo 
    assert "presenter_key1#3" [ presenter/expr-debug-string ] ""
    presenter/redo
    presenter/push-key 'add
    presenter/push-key 'n2
    assert "presenter_key1#4" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/push-key 'add
    assert "presenter_key1#5" [ presenter/expr-debug-string ] "1 + 2 [ + ] = 3"
    presenter/undo
    assert "presenter_key1#6" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/redo
    presenter/push-key 'backspace
    assert "presenter_key1#7" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/undo
    assert "presenter_key1#8" [ presenter/expr-debug-string ] "1 + 2 [ + ] = 3"
    presenter/redo
    presenter/push-key 'backspace
    presenter/push-key 'backspace
    presenter/push-key 'backspace
    presenter/push-key 'backspace
    presenter/push-key 'backspace
    assert "presenter_key1#9" [ presenter/expr-debug-string ] ""
    presenter/undo
    assert "presenter_key1#10" [ presenter/expr-debug-string ] "1 = 1"

    ; key2 : push-key with paren
    presenter/reset
    presenter/push-key 'n1
    presenter/push-key 'add
    presenter/push-key 'n2
    presenter/push-key 'paren-r
    presenter/push-key 'n3
    assert "presenter_key2#1" [ presenter/expr-debug-string ] "1 + 2 [ )3 ] = 3"
    presenter/undo
    presenter/undo
    presenter/push-key 'paren-l
    presenter/push-key 'n3
    presenter/push-key 'add
    presenter/push-key 'n4
    presenter/push-key 'paren-r
    assert "presenter_key2#2" [ presenter/expr-debug-string ] "1 + 2 ⋅ (3 + 4) = 15"
    presenter/undo
    assert "presenter_key2#3" [ presenter/expr-debug-string ] "1 + 2 [ (3+4 ] = 3"
    presenter/redo
    assert "presenter_key2#4" [ presenter/expr-debug-string ] "1 + 2 ⋅ (3 + 4) = 15"
    presenter/backspace
    presenter/push-key 'add
    presenter/push-key 'n5
    presenter/push-key 'paren-r
    assert "presenter_key2#5" [ presenter/expr-debug-string ] "1 + 2 ⋅ (3 + 4 + 5) = 25"

    ; key3 : push-key and clear-expr
    presenter/reset
    presenter/push-key 'n1
    presenter/push-key 'add
    presenter/push-key 'n2
    presenter/push-key 'clear-expr
    presenter/push-key 'n3
    presenter/push-key 'multiply
    presenter/push-key 'n4
    assert "presenter_key3#1" [ presenter/expr-debug-string ] "3 × 4 = 12"
    presenter/push-key 'clear-expr
    assert "presenter_key3#2" [ presenter/expr-debug-string ] ""
    presenter/undo
    assert "presenter_key3#3" [ presenter/expr-debug-string ] "3 × 4 = 12"
    presenter/push-key 'clear-expr
    assert "presenter_key3#4" [ presenter/expr-debug-string ] ""
    presenter/push-key 'clear-expr
    assert "presenter_key3#5" [ presenter/expr-debug-string ] ""
    presenter/undo
    assert "presenter_key3#6" [ presenter/expr-debug-string ] "3 × 4 = 12"

    ; key4 : key-entry with undo
    presenter/reset
    presenter/key-entry 'n3
    presenter/key-entry 'n0
    presenter/key-entry 'sine-d
    presenter/key-entry 'add
    presenter/key-entry 'n1
    assert "presenter_key4#1" [ presenter/expr-debug-string ] "sin₀30 + 1 = 1.5"
    presenter/undo ; n1
    assert "presenter_key4#2" [ presenter/expr-debug-string ] "sin₀30 [ + ] = 0.5"
    presenter/undo ; add
    assert "presenter_key4#3" [ presenter/expr-debug-string ] "sin₀30 = 0.5"
    presenter/redo ; add
    assert "presenter_key4#4" [ presenter/expr-debug-string ] "sin₀30 [ + ] = 0.5"
    presenter/redo ; n1
    assert "presenter_key4#5" [ presenter/expr-debug-string ] "sin₀30 + 1 = 1.5"
    presenter/redo ; nothing
    assert "presenter_key4#6" [ presenter/expr-debug-string ] "sin₀30 + 1 = 1.5"
    presenter/key-entry 'n0
    assert "presenter_key4#7" [ presenter/expr-debug-string ] "sin₀30 + 10 = 10.5"
    presenter/undo presenter/undo presenter/undo presenter/undo ; n0 n1 add sin-d
    assert "presenter_key4#8" [ presenter/expr-debug-string ] "30 = 30"
    presenter/undo presenter/undo ; n0 n3
    assert "presenter_key4#9" [ presenter/expr-debug-string ] ""
    presenter/undo ; nothing
    assert "presenter_key4#10" [ presenter/expr-debug-string ] ""
    presenter/redo presenter/redo presenter/redo presenter/redo presenter/redo presenter/redo ; n3 n0 sine-d add n1 n0
    assert "presenter_key4#11" [ presenter/expr-debug-string ] "sin₀30 + 10 = 10.5"
    presenter/redo ; nothing
    assert "presenter_key4#12" [ presenter/expr-debug-string ] "sin₀30 + 10 = 10.5"

    ; key5 : backspace with undo
    presenter/reset
    presenter/key-entry 'n1
    assert "presenter_key5#1" [ presenter/expr-debug-string ] "1 = 1"
    presenter/backspace ; n1
    assert "presenter_key5#2" [ presenter/expr-debug-string ] ""
    presenter/undo ; backspace
    assert "presenter_key5#3" [ presenter/expr-debug-string ] "1 = 1"
    presenter/redo ; backspace
    assert "presenter_key5#4" [ presenter/expr-debug-string ] ""
    presenter/key-entry 'n2
    assert "presenter_key5#5" [ presenter/expr-debug-string ] "2 = 2"
    presenter/undo ; n2
    assert "presenter_key5#6" [ presenter/expr-debug-string ] ""
    presenter/undo ; backspace
    assert "presenter_key5#7" [ presenter/expr-debug-string ] "1 = 1"
    presenter/key-entry 'n3 ; kill previous undos
    assert "presenter_key5#8" [ presenter/expr-debug-string ] "13 = 13"
    presenter/undo ; n3
    assert "presenter_key5#9" [ presenter/expr-debug-string ] "1 = 1"
    presenter/undo ; n1
    assert "presenter_key5#10" [ presenter/expr-debug-string ] ""
    presenter/redo ; n1
    assert "presenter_key5#11" [ presenter/expr-debug-string ] "1 = 1"
    presenter/redo ; n3
    assert "presenter_key5#12" [ presenter/expr-debug-string ] "13 = 13"
    presenter/redo ; nothing
    assert "presenter_key5#13" [ presenter/expr-debug-string ] "13 = 13"

    ; key6: clear-expr with undo
    presenter/reset
    presenter/key-entry 'n1
    presenter/key-entry 'add
    presenter/key-entry 'n2
    assert "presenter_key6#1" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/clear-expr
    assert "presenter_key6#2" [ presenter/expr-debug-string ] ""
    presenter/undo ; clear-expr
    assert "presenter_key6#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/redo ; clear-expr
    assert "presenter_key6#4" [ presenter/expr-debug-string ] ""
    presenter/undo ; clear-expr
    assert "presenter_key6#5" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/key-entry 'n3
    assert "presenter_key6#6" [ presenter/expr-debug-string ] "1 + 23 = 24"
    presenter/undo ; n3
    assert "presenter_key6#7" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/undo ; n2
    assert "presenter_key6#8" [ presenter/expr-debug-string ] "1 [ + ] = 1"

    ; enter1
    presenter/reset
    assert "presenter_enter1#1" [ presenter/expr-index ] 0
    presenter/push-key 'n1
    presenter/push-key 'add
    presenter/push-key 'n2
    presenter/enter
    assert "presenter_enter1#2" [ presenter/expr-debug-string ] ""
    assert "presenter_enter1#3" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    assert "presenter_enter1#4" [ presenter/expr-index ] 1
    presenter/push-key 'n4
    presenter/push-key 'add
    assert "presenter_enter1#5" [ presenter/expr-debug-string ] "4 [ + ] = 4"
    assert "presenter_enter1#6" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    presenter/enter
    assert "presenter_enter1#8" [ presenter/expr-debug-string ] "[ + ]"
    assert "presenter_enter1#9" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "4 = 4" ]
    assert "presenter_enter1#10" [ presenter/expr-index ] 2
    presenter/undo
    assert "presenter_enter1#11" [ presenter/expr-debug-string ] ""
    assert "presenter_enter1#12" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "4 = 4" ]
    assert "presenter_enter1#13" [ presenter/expr-index ] 2
    presenter/undo
    assert "presenter_enter1#14" [ presenter/expr-debug-string ] "4 = 4"
    assert "presenter_enter1#15" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "4 = 4"]
    assert "presenter_enter1#16" [ presenter/expr-index ] 2
    presenter/undo
    assert "presenter_enter1#17" [ presenter/expr-debug-string ] ""
    assert "presenter_enter1#18" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    assert "presenter_enter1#19" [ presenter/expr-index ] 1
    presenter/undo
    assert "presenter_enter1#20" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_enter1#21" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    presenter/undo
    assert "presenter_enter1#22" [ presenter/expr-debug-string ] ""
    assert "presenter_enter1#23" [ presenter/expr-stack-debug ] [ ]
    assert "presenter_enter1#24" [ presenter/expr-index ] 0

    ; enter2
    presenter/reset
    presenter/push-key 'n4
    presenter/push-key 'add
    presenter/push-key 'n5
    presenter/enter
    assert "presenter_enter2#1" [ presenter/expr-debug-string ] ""
    assert "presenter_enter2#2" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" ]
    assert "presenter_enter2#8" [ presenter/expr-index ] 1
    presenter/push-key 'n4
    presenter/push-key 'square-2
    presenter/sel-expr 0
    presenter/enter
    assert "presenter_enter2#3" [ presenter/expr-debug-string ] ""
    assert "presenter_enter2#4" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" "√4 = 2" ]
    assert "presenter_enter2#8" [ presenter/expr-index ] 2
    presenter/push-key 'n5
    presenter/push-key 'multiply
    presenter/push-key 'n6
    presenter/push-key 'power-2
    assert "presenter_enter2#5" [ presenter/expr-debug-string ] "5 × 6² = 180"
    presenter/sel-expr 1
    presenter/enter
    assert "presenter_enter2#6" [ presenter/expr-debug-string ] ""
    assert "presenter_enter2#7" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" "5 × 6² = 180" "√4 = 2" ]
    assert "presenter_enter2#8" [ presenter/expr-index ] 2
    presenter/undo
    presenter/undo ; add line 1
    assert "presenter_enter2#9" [ presenter/expr-debug-string ] ""
    assert "presenter_enter2#10" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" "√4 = 2" ]
    assert "presenter_enter2#11" [ presenter/expr-index ] 1
    presenter/undo
    presenter/undo ; insert line 2
    assert "presenter_enter2#12" [ presenter/expr-debug-string ] ""
    assert "presenter_enter2#13" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" ]
    assert "presenter_enter2#14" [ presenter/expr-index ] 0
    presenter/redo
    presenter/redo
    presenter/redo
    presenter/redo
    assert "presenter_enter2#15" [ presenter/expr-debug-string ] ""
    assert "presenter_enter2#16" [ presenter/expr-stack-debug ] [ "4 + 5 = 9" "5 × 6² = 180" "√4 = 2" ]
    assert "presenter_enter2#17" [ presenter/expr-index ] 2

    ; enter3
    presenter/reset
    presenter/push-key 'n1
    presenter/push-key 'add
    presenter/push-key 'n2
    presenter/push-key 'add
    presenter/enter
    assert "presenter_enter3#1" [ presenter/expr-debug-string ] "[ + ]"
    assert "presenter_enter3#2" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    presenter/backspace
    presenter/push-key 'n3
    presenter/push-key 'factorial
    presenter/enter
    assert "presenter_enter3#3" [ presenter/expr-debug-string ] ""
    assert "presenter_enter3#4" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "3! = 6" ]

    ; enter4 with undo
    presenter/reset
    presenter/key-entry 'n1
    presenter/enter
    presenter/key-entry 'n2
    presenter/enter
    assert "presenter_enter4#1" [ presenter/expr-debug-string ] ""
    assert "presenter_enter4#2" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
    presenter/undo ; enter-2 - n2
    assert "presenter_enter4#3" [ presenter/expr-debug-string ] "2 = 2"
    assert "presenter_enter4#4" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
    presenter/undo ; enter-1 - n2
    assert "presenter_enter4#5" [ presenter/expr-debug-string ] ""
    assert "presenter_enter4#6" [ presenter/expr-stack-debug ] ["1 = 1"]
    presenter/undo ; enter-2 - n1
    assert "presenter_enter4#7" [ presenter/expr-debug-string ] "1 = 1"
    assert "presenter_enter4#8" [ presenter/expr-stack-debug ] ["1 = 1"]
    presenter/undo ; enter-1 - n1
    assert "presenter_enter4#9" [ presenter/expr-debug-string ] "" ; 1 = 1
    assert "presenter_enter4#10" [ presenter/expr-stack-debug ] [] ; 1 = 1
    presenter/undo ; nothing
    assert "presenter_enter4#11" [ presenter/expr-debug-string ] "" ; 1 = 1
    assert "presenter_enter4#12" [ presenter/expr-stack-debug ] []
    presenter/redo ; enter-1 - n1
    assert "presenter_enter4#13" [ presenter/expr-debug-string ] "1 = 1"
    assert "presenter_enter4#14" [ presenter/expr-stack-debug ] ["1 = 1"]
    presenter/redo ; enter-2 - n1
    assert "presenter_enter4#15" [ presenter/expr-debug-string ] ""
    assert "presenter_enter4#16" [ presenter/expr-stack-debug ] ["1 = 1"]
    presenter/redo ; enter-1 - n2
    assert "presenter_enter4#17" [ presenter/expr-debug-string ] "2 = 2"
    assert "presenter_enter4#18" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
    presenter/redo ; enter-2 - n2
    assert "presenter_enter4#19" [ presenter/expr-debug-string ] ""
    assert "presenter_enter4#20" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
    presenter/redo ; nothing
    assert "presenter_enter4#21" [ presenter/expr-debug-string ] ""
    assert "presenter_enter4#22" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
    presenter/undo ; enter-2 - n2
    assert "presenter_enter4#23" [ presenter/expr-debug-string ] "2 = 2"
    assert "presenter_enter4#24" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]

    ; enter5 : enter with failed characters and undo
    presenter/reset
    presenter/key-entry 'n1
    presenter/key-entry 'add
    presenter/key-entry 'n2
    presenter/key-entry 'multiply
    assert "presenter_enter5#1" [ presenter/expr-debug-string ] "1 + 2 [ × ] = 3"
    assert "presenter_enter5#2" [ presenter/expr-stack-debug ] []
    presenter/enter
    assert "presenter_enter5#3" [ presenter/expr-debug-string ] "[ × ]"
    assert "presenter_enter5#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; enter
    assert "presenter_enter5#5" [ presenter/expr-debug-string ] ""
    assert "presenter_enter5#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/key-entry 'n3
    assert "presenter_enter5#7" [ presenter/expr-debug-string ] "3 = 3"
    assert "presenter_enter5#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; n3
    assert "presenter_enter5#9" [ presenter/expr-debug-string ] ""
    assert "presenter_enter5#10" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; enter-2
    assert "presenter_enter5#11" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_enter5#12" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; enter-1
    assert "presenter_enter5#13" [ presenter/expr-debug-string ] ""
    assert "presenter_enter5#14" [ presenter/expr-stack-debug ] []
    presenter/undo ; nothing
    assert "presenter_enter5#15" [ presenter/expr-debug-string ] ""
    assert "presenter_enter5#16" [ presenter/expr-stack-debug ] []
    presenter/redo ; enter-1
    assert "presenter_enter5#17" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_enter5#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/redo ; enter-2 === useful ?
    assert "presenter_enter5#17" [ presenter/expr-debug-string ] ""
    assert "presenter_enter5#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/redo ; n3
    assert "presenter_enter5#7" [ presenter/expr-debug-string ] "3 = 3"
    assert "presenter_enter5#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/redo ; nothing
    assert "presenter_enter5#7" [ presenter/expr-debug-string ] "3 = 3"
    assert "presenter_enter5#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]

    ; load1 : load-expr and modification
    presenter/reset
    assert "presenter_load1#1" [ presenter/linked-expr ] false
    presenter/push-key 'n1
    presenter/push-key 'add
    presenter/push-key 'n2
    presenter/push-key 'add
    presenter/enter
    assert "presenter_load1#1" [ presenter/expr-debug-string ] "[ + ]"
    assert "presenter_load1#2" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    assert "presenter_load1#3" [ presenter/expr-index] 1
    assert "presenter_load1#4" [ presenter/linked-expr ] false
    presenter/load-expr
    assert "presenter_load1#5" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load1#6" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    assert "presenter_load1#7" [ presenter/expr-index] 1
    assert "presenter_load1#8" [ presenter/linked-expr ] true
    presenter/undo ; load-expr
    assert "presenter_load1#9" [ presenter/expr-debug-string ] "[ + ]"
    assert "presenter_load1#10" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    assert "presenter_load1#11" [ presenter/expr-index] 1
    assert "presenter_load1#12" [ presenter/linked-expr ] false
    presenter/redo ; load-expr
    presenter/push-key 'add
    presenter/push-key 'n3
    presenter/sel-expr 0
    assert "presenter_load1#13" [ presenter/linked-expr ] false
    presenter/enter ; enter - add and clear
    assert "presenter_load1#14" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "1 + 2 + 3 = 6" ]
    presenter/undo ; enter1 - clear
    assert "presenter_load1#15" [ presenter/expr-debug-string ] "1 + 2 + 3 = 6"
    assert "presenter_load1#16" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "1 + 2 + 3 = 6" ]
    assert "presenter_load1#17" [ presenter/expr-index] 2
    assert "presenter_load1#18" [ presenter/linked-expr ] true
    presenter/undo ; enter2 - add
    assert "presenter_load1#19" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load1#20" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" ]
    assert "presenter_load1#21" [ presenter/linked-expr ] false
    presenter/redo
    presenter/redo
    presenter/sel-expr 1
    presenter/load-expr
    assert "presenter_load1#22" [ presenter/expr-debug-string ] "1 + 2 = 3"
    presenter/backspace
    presenter/push-key 'n4
    presenter/enter ; modify and clear
    assert "presenter_load1#23" [ presenter/expr-debug-string ] ""
    assert "presenter_load1#24" [ presenter/expr-stack-debug ] [ "1 + 4 = 5" "1 + 2 + 3 = 6" ]
    presenter/undo ; enter1 - clear
    assert "presenter_load1#25" [ presenter/expr-debug-string ] "1 + 4 = 5"
    assert "presenter_load1#26" [ presenter/expr-stack-debug ] [ "1 + 4 = 5" "1 + 2 + 3 = 6" ]
    assert "presenter_load1#27" [ presenter/linked-expr ] true
    presenter/undo ; enter2 - modify
    assert "presenter_load1#28" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load1#29" [ presenter/expr-stack-debug ] [ "1 + 2 = 3" "1 + 2 + 3 = 6" ]
    assert "presenter_load1#30" [ presenter/linked-expr ] true
    presenter/redo ; modify
    presenter/redo ; clear
    presenter/push-key 'n5
    presenter/enter ; enter : add and clear
    assert "presenter_load1#31" [ presenter/expr-debug-string ] ""
    assert "presenter_load1#32" [ presenter/expr-stack-debug ] [ "1 + 4 = 5" "5 = 5" "1 + 2 + 3 = 6" ]
    presenter/undo ; enter1 - clear
    assert "presenter_load1#33" [ presenter/expr-debug-string ] "5 = 5"
    assert "presenter_load1#34" [ presenter/expr-stack-debug ] [ "1 + 4 = 5" "5 = 5" "1 + 2 + 3 = 6" ]
    assert "presenter_load1#35" [ presenter/linked-expr ] true
    presenter/push-key 'add
    presenter/push-key 'n6
    presenter/enter ; enter : modify and clear
    assert "presenter_load1#36" [ presenter/expr-debug-string ] "" ; @ZWT - correct when ran manually !
    assert "presenter_load1#37" [ presenter/expr-stack-debug ] [ "1 + 4 = 5" "5 + 6 = 11" "1 + 2 + 3 = 6" ]
    presenter/load-expr
    presenter/sel-expr 2
    presenter/enter ; enter : dup
    assert "presenter_load1#38" [ presenter/expr-debug-string ] ""
    assert "presenter_load1#39" [ presenter/expr-stack-debug ] [ "1 + 4 = 5" "5 + 6 = 11" "5 + 6 = 11" "1 + 2 + 3 = 6" ]
    assert "presenter_load1#40" [ presenter/expr-index ] 3

    ; load2 with clear-expr
    presenter/reset
    presenter/key-entry 'n1
    presenter/key-entry 'add
    presenter/key-entry 'n2
    presenter/enter
    presenter/push-key 'n4
    presenter/push-key 'add
    presenter/push-key 'n5
    presenter/enter
    assert "presenter_load2#1" [ presenter/expr-debug-string ] ""
    assert "presenter_load2#2" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
    presenter/sel-expr 1
    presenter/load-expr
    assert "presenter_load2#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load2#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
    presenter/clear-expr
    assert "presenter_load2#5" [ presenter/expr-debug-string ] ""
    assert "presenter_load2#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
    presenter/clear-expr
    assert "presenter_load2#7" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
    presenter/sel-expr 1
    presenter/load-expr
    presenter/backspace
    presenter/backspace
    presenter/backspace
    assert "presenter_load2#8" [ presenter/expr-debug-string ] ""
    presenter/enter
    assert "presenter_load2#9" [ presenter/expr-debug-string ] ""
    assert "presenter_load2#10" [ presenter/expr-stack-debug ] [ ]

    ; load3 : load-expr, clear-expr, undo
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
    presenter/load-expr
    presenter/clear-expr
    presenter/clear-expr
    assert "presenter_load3#1" [ presenter/expr-debug-string ] ""
    assert "presenter_load3#2" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
    assert "presenter_load3#3" [ presenter/expr-index ] 1
    presenter/undo ; remove line
    assert "presenter_load3#4" [ presenter/expr-debug-string ] ""
    assert "presenter_load3#5" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
    assert "presenter_load3#6" [ presenter/expr-index ] 1
    presenter/undo ; clear buffer
    assert "presenter_load3#7" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load3#8" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "4 + 5 = 9"]
    presenter/redo ; clear buffer 
    presenter/redo ; remove line
    assert "presenter_load3#9" [ presenter/expr-debug-string ] ""
    assert "presenter_load3#10" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
    presenter/load-expr
    presenter/backspace
    assert "presenter_load3#11" [ presenter/expr-debug-string ] "4 [ + ] = 4"
    presenter/clear-expr ; only buffer
    assert "presenter_load3#12" [ presenter/expr-debug-string ] ""
    assert "presenter_load3#13" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
    presenter/undo ; clear-expr - only buffer
    assert "presenter_load3#14" [ presenter/expr-debug-string ] "4 [ + ] = 4"
    assert "presenter_load3#15" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
    assert "presenter_load3#16" [ presenter/expr-index ] 1
    assert "presenter_load3#17" [ presenter/linked-expr ] true
    presenter/backspace
    presenter/backspace
    presenter/enter
    assert "presenter_load3#18" [ presenter/expr-debug-string ] ""
    assert "presenter_load3#19" [ presenter/expr-stack-debug ] [ ]
    presenter/undo
    assert "presenter_load3#20" [ presenter/expr-debug-string ] ""
    assert "presenter_load3#21" [ presenter/expr-stack-debug ] ["4 + 5 = 9"]
    assert "presenter_load3#22" [ presenter/expr-index ] 1
    assert "presenter_load3#23" [ presenter/linked-expr ] true

    ; load4 : load-expr with undo
    presenter/reset
    presenter/push-key 'n1
    presenter/push-key 'add
    presenter/push-key 'n2
    presenter/enter ; #1
    presenter/push-key 'n3
    presenter/push-key 'subtract
    presenter/push-key 'n4
    presenter/enter ; #2
    assert "presenter_load4#1" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#2" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/sel-expr 1 ; sel line 1
    presenter/load-expr
    assert "presenter_load4#3" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load4#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/push-key 'add
    presenter/push-key 'n4
    assert "presenter_load4#5" [ presenter/expr-debug-string ] "1 + 2 + 4 = 7"
    assert "presenter_load4#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/enter ; #3 - 1+2=3 => 1+2+4=7
    assert "presenter_load4#7" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#8" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]
    presenter/undo ; #3 - enter 2 (clear)
    assert "presenter_load4#9" [ presenter/expr-debug-string ] "1 + 2 + 4 = 7"
    assert "presenter_load4#10" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]
    presenter/undo ; #3 - enter 1 - 1+2+4=7 => 1+2=3
    assert "presenter_load4#11" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load4#12" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/undo ; load-expr
    assert "presenter_load4#13" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#14" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/undo ; #2 - 2
    assert "presenter_load4#15" [ presenter/expr-debug-string ] "3 − 4 = -1"
    assert "presenter_load4#16" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/undo ; #2 - 1
    assert "presenter_load4#17" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; #1 - 2
    assert "presenter_load4#19" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load4#20" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; #1 - 1
    assert "presenter_load4#21" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#22" [ presenter/expr-stack-debug ] []
    presenter/redo ; #1 - 1
    assert "presenter_load4#23" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load4#24" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; #1 - 1
    assert "presenter_load4#25" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#26" [ presenter/expr-stack-debug ] []
    presenter/redo presenter/redo ; #1
    assert "presenter_load4#27" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#28" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/redo presenter/redo ; #2
    assert "presenter_load4#29" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#30" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/redo ; load-expr
    assert "presenter_load4#31" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_load4#32" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "3 − 4 = -1"]
    presenter/redo presenter/redo ; #3
    assert "presenter_load4#33" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#34" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]
    presenter/redo ; nothing
    assert "presenter_load4#35" [ presenter/expr-debug-string ] ""
    assert "presenter_load4#36" [ presenter/expr-stack-debug ] ["1 + 2 + 4 = 7" "3 − 4 = -1"]

    ; load5 : enter undo redo and linked-expr
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/undo ; clear-buffer
    assert "presenter_load5#1" [ presenter/expr-debug-string ] "1 = 1"
    assert "presenter_load5#2" [ presenter/expr-stack-debug ] ["1 = 1"]
    assert "presenter_load5#3" [ presenter/expr-index ] 1
    assert "presenter_load5#4" [ presenter/linked-expr ] true
    presenter/redo ; clear buffer
    assert "presenter_load5#5" [ presenter/expr-debug-string ] ""
    assert "presenter_load5#6" [ presenter/expr-stack-debug ] ["1 = 1"]
    assert "presenter_load5#7" [ presenter/expr-index ] 1
    assert "presenter_load5#8" [ presenter/linked-expr ] false
    presenter/undo ; clear buffer
    presenter/push-key 'opposite
    presenter/enter
    assert "presenter_load5#9" [ presenter/expr-debug-string ] ""
    assert "presenter_load5#10" [ presenter/expr-stack-debug ] ["-1 = -1"]
    assert "presenter_load5#11" [ presenter/expr-index ] 1
    assert "presenter_load5#12" [ presenter/linked-expr ] false
    presenter/undo ; clear buffer
    assert "presenter_load5#13" [ presenter/expr-debug-string ] "-1 = -1"
    assert "presenter_load5#14" [ presenter/expr-stack-debug ] ["-1 = -1"]
    assert "presenter_load5#15" [ presenter/expr-index ] 1
    assert "presenter_load5#16" [ presenter/linked-expr ] true
    presenter/undo ; modify line
    assert "presenter_load5#17" [ presenter/expr-debug-string ] "1 = 1"
    assert "presenter_load5#18" [ presenter/expr-stack-debug ] ["1 = 1"]
    assert "presenter_load5#19" [ presenter/expr-index ] 1
    assert "presenter_load5#20" [ presenter/linked-expr ] true
    presenter/redo ; modify line
    assert "presenter_load5#21" [ presenter/expr-debug-string ] "-1 = -1"
    assert "presenter_load5#22" [ presenter/expr-stack-debug ] ["-1 = -1"]
    assert "presenter_load5#23" [ presenter/expr-index ] 1
    assert "presenter_load5#24" [ presenter/linked-expr ] true
    presenter/push-key 'add
    presenter/push-key 'n1
    presenter/enter
    assert "presenter_load5#25" [ presenter/expr-debug-string ] ""
    assert "presenter_load5#26" [ presenter/expr-stack-debug ] ["-1 + 1 = 0"]
    assert "presenter_load5#27" [ presenter/expr-index ] 1
    assert "presenter_load5#28" [ presenter/linked-expr ] false

    ; clear-all
    presenter/reset
    presenter/clear-all
    assert "presenter_clearall#1" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall#2" [ presenter/expr-stack-debug ] []
    presenter/push-key 'n9
    presenter/push-key 'n0 
    presenter/push-key 'cosine-d
    assert "presenter_clearall#3" [ presenter/expr-debug-string ] "cos₀90 = 0"
    assert "presenter_clearall#4" [ presenter/expr-stack-debug ] []
    presenter/enter
    assert "presenter_clearall#5" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall#6" [ presenter/expr-stack-debug ] [ "cos₀90 = 0" ]

    ; clearall2 : clear-all with undo
    presenter/reset
    presenter/key-entry 'n1
    presenter/key-entry 'add
    presenter/key-entry 'n2
    presenter/enter ; #1
    assert "presenter_clearall2#1" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#2" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/key-entry 'n3
    presenter/key-entry 'n0
    presenter/key-entry 'sine-d
    assert "presenter_clearall2#3" [ presenter/expr-debug-string ] "sin₀30 = 0.5"
    assert "presenter_clearall2#4" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/enter ; #2
    assert "presenter_clearall2#5" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#6" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
    presenter/clear-all
    assert "presenter_clearall2#7" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#8" [ presenter/expr-stack-debug ] []
    presenter/undo ; clear-all
    assert "presenter_clearall2#9" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#10" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
    presenter/redo ; clear-all
    assert "presenter_clearall2#11" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#12" [ presenter/expr-stack-debug ] []
    presenter/key-entry 'n4
    presenter/key-entry 'factorial
    presenter/enter ; #3
    assert "presenter_clearall2#13" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#14" [ presenter/expr-stack-debug ] ["4! = 24"]
    presenter/undo ; enter-2 #3
    assert "presenter_clearall2#15" [ presenter/expr-debug-string ] "4! = 24"
    assert "presenter_clearall2#16" [ presenter/expr-stack-debug ] ["4! = 24"]
    presenter/undo ; enter-1 #3
    assert "presenter_clearall2#15" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#16" [ presenter/expr-stack-debug ] []
    presenter/undo ; clear-all
    assert "presenter_clearall2#17" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#18" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
    presenter/undo ; enter-2 #2
    assert "presenter_clearall2#19" [ presenter/expr-debug-string ] "sin₀30 = 0.5"
    assert "presenter_clearall2#20" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "sin₀30 = 0.5"]
    presenter/undo ; enter-1 #2
    assert "presenter_clearall2#21" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#22" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/key-entry 'n5
    presenter/enter ; #4
    presenter/key-entry 'n6
    presenter/key-entry 'add
    presenter/key-entry 'add
    assert "presenter_clearall2#23" [ presenter/expr-debug-string ] "6 [ ++ ] = 6"
    assert "presenter_clearall2#24" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
    presenter/clear-all
    assert "presenter_clearall2#25" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#26" [ presenter/expr-stack-debug ] []
    presenter/undo ; clear-all
    assert "presenter_clearall2#27" [ presenter/expr-debug-string ] "6 [ ++ ] = 6"
    assert "presenter_clearall2#28" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
    presenter/key-entry 'n7
    assert "presenter_clearall2#29" [ presenter/expr-debug-string ] "6 [ ++7 ] = 6"
    assert "presenter_clearall2#30" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
    presenter/undo
    presenter/undo
    presenter/undo
    presenter/undo ; n7 + + 6
    assert "presenter_clearall2#31" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#32" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
    presenter/undo ; enter-2 #4
    assert "presenter_clearall2#33" [ presenter/expr-debug-string ] "5 = 5"
    assert "presenter_clearall2#34" [ presenter/expr-stack-debug ] ["1 + 2 = 3" "5 = 5"]
    presenter/undo ; enter-1 #4
    assert "presenter_clearall2#35" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#36" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; enter-2 #1
    assert "presenter_clearall2#37" [ presenter/expr-debug-string ] "1 + 2 = 3"
    assert "presenter_clearall2#38" [ presenter/expr-stack-debug ] ["1 + 2 = 3"]
    presenter/undo ; enter-1 #1
    assert "presenter_clearall2#39" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#40" [ presenter/expr-stack-debug ] []
    presenter/undo ; nothing
    assert "presenter_clearall2#41" [ presenter/expr-debug-string ] ""
    assert "presenter_clearall2#42" [ presenter/expr-stack-debug ] []

    ; sel up-sel down-sel no-sel
    presenter/reset
    assert "presenter_sel#1" [ presenter/expr-index ] 0
    presenter/push-key 'n1
    assert "presenter_sel#2" [ presenter/expr-index ] 0
    presenter/enter
    assert "presenter_sel#3" [ presenter/expr-index ] 1
    presenter/push-key 'n2
    presenter/enter
    assert "presenter_sel#4" [ presenter/expr-index ] 2
    presenter/push-key 'n3
    presenter/enter
    presenter/sel-expr 0
    assert "presenter_sel#5" [ presenter/expr-index ] 0
    presenter/up-sel
    assert "presenter_sel#6" [ presenter/expr-index ] 3
    presenter/undo
    assert "presenter_sel#7" [ presenter/expr-index ] 0
    presenter/redo
    presenter/up-sel
    assert "presenter_sel#8" [ presenter/expr-index ] 2
    presenter/up-sel
    assert "presenter_sel#9" [ presenter/expr-index ] 1
    presenter/up-sel
    assert "presenter_sel#10" [ presenter/expr-index ] 3
    presenter/down-sel
    assert "presenter_sel#11" [ presenter/expr-index ] 1
    presenter/down-sel
    assert "presenter_sel#12" [ presenter/expr-index ] 2
    presenter/undo
    assert "presenter_sel#13" [ presenter/expr-index ] 1
    presenter/redo
    assert "presenter_sel#14" [ presenter/expr-index ] 2
    presenter/sel-expr 0
    presenter/down-sel
    assert "presenter_sel#15" [ presenter/expr-index ] 1
    presenter/no-sel
    assert "presenter_sel#16" [ presenter/expr-index ] 0
    presenter/undo
    assert "presenter_sel#17" [ presenter/expr-index ] 1

    ; unary operator on stack
    presenter/reset
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'power-2
    assert "presenter_unary#1" [ presenter/expr-debug-string ] ""
    assert "presenter_unary#2" [ presenter/expr-stack-debug ] ["(2)² = 4"]
    presenter/undo
    assert "presenter_unary#3" [ presenter/expr-stack-debug ] ["2 = 2"]
    presenter/push-key 'n3
    presenter/enter
    presenter/push-key 'power-2
    assert "presenter_unary#4" [ presenter/expr-stack-debug ] ["2 = 2" "(3)² = 9"]
    presenter/sel-expr 1
    presenter/push-key 'power-2
    assert "presenter_unary#5" [ presenter/expr-stack-debug ] ["(2)² = 4" "(3)² = 9"]
    presenter/undo
    assert "presenter_unary#6" [ presenter/expr-stack-debug ] ["2 = 2" "(3)² = 9"]
    presenter/undo
    assert "presenter_unary#7" [ presenter/expr-stack-debug ] ["2 = 2" "3 = 3"]
    
    ; binary operator on stack
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'add
    assert "presenter_binary#1" [ presenter/expr-debug-string ] ""
    assert "presenter_binary#2" [ presenter/expr-stack-debug ] ["(1) + (2) = 3"]
    presenter/undo
    assert "presenter_binary#3" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2"]
    presenter/push-key 'n3
    presenter/enter
    presenter/push-key 'add
    assert "presenter_binary#4" [ presenter/expr-debug-string ] ""
    assert "presenter_binary#5" [ presenter/expr-stack-debug ] ["1 = 1" "(2) + (3) = 5"]
    presenter/undo
    assert "presenter_binary#6" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2" "3 = 3"]
    presenter/sel-expr 2
    presenter/push-key 'add
    assert "presenter_binary#7" [ presenter/expr-stack-debug ] ["(1) + (2) = 3" "3 = 3"]
    presenter/undo
    assert "presenter_binary#8" [ presenter/expr-stack-debug ] ["1 = 1" "2 = 2" "3 = 3"]

    ; dup-expr
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/sel-expr 0
    presenter/enter
    assert "presenter_dup#1" [ presenter/expr-debug-string ] ""
    assert "presenter_dup#2" [ presenter/expr-stack-debug ] ["1 = 1" "1 = 1"]
    presenter/undo
    assert "presenter_dup#3" [ presenter/expr-debug-string ] ""
    assert "presenter_dup#4" [ presenter/expr-stack-debug ] ["1 = 1"]
    presenter/push-key 'add
    assert "presenter_dup#5" [ presenter/expr-debug-string ] "[ + ]"
    presenter/enter
    assert "presenter_dup#6" [ presenter/expr-debug-string ] "[ + ]"
    assert "presenter_dup#7" [ presenter/expr-stack-debug ] ["1 = 1"]
    presenter/undo
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'n3
    presenter/enter
    assert "presenter_dup#8" [ presenter/expr-debug-string ] ""
    assert "presenter_dup#9" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    presenter/sel-expr 1
    presenter/enter
    assert "presenter_dup#8" [ presenter/expr-debug-string ] ""
    assert "presenter_dup#9" [ presenter/expr-stack-debug ] [ "1 = 1" "1 = 1" "2 = 2" "3 = 3" ]
    assert "presenter_dup#10" [ presenter/expr-index ] 2
    presenter/undo
    assert "presenter_dup#11" [ presenter/expr-debug-string ] ""
    assert "presenter_dup#12" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    assert "presenter_dup#13" [ presenter/expr-index ] 1

    ; swap-expr
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'n3
    presenter/enter
    presenter/push-key 'n4
    presenter/enter
    presenter/sel-expr 0
    presenter/swap-expr
    assert "presenter_swap#1" [ presenter/expr-stack-debug ] [ "4 = 4" "2 = 2" "3 = 3" "1 = 1" ]
    assert "presenter_swap#2" [ presenter/expr-index ] 4
    presenter/undo
    assert "presenter_swap#3" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]
    assert "presenter_swap#4" [ presenter/expr-index ] 0
    presenter/redo
    assert "presenter_swap#5" [ presenter/expr-stack-debug ] [ "4 = 4" "2 = 2" "3 = 3" "1 = 1" ]
    presenter/swap-expr
    assert "presenter_swap#6" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]
    presenter/sel-expr 2
    presenter/swap-expr
    assert "presenter_swap#7" [ presenter/expr-stack-debug ] [ "1 = 1" "4 = 4" "3 = 3" "2 = 2" ]
    presenter/undo
    assert "presenter_swap#8" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]
    presenter/sel-expr 3
    presenter/swap-expr
    assert "presenter_swap#9" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "4 = 4" "3 = 3" ]
    presenter/swap-expr
    assert "presenter_swap#10" [ presenter/expr-stack-debug ] [ "3 = 3" "2 = 2" "4 = 4" "1 = 1" ]
    presenter/sel-expr 1
    presenter/swap-expr
    presenter/sel-expr 3
    presenter/swap-expr
    assert "presenter_swap#11" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]

    ; move1 : up-expr down-expr
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'n3
    presenter/enter
    presenter/sel-expr 0
    presenter/up-expr
    assert "presenter_move1#1" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "2 = 2" ]
    presenter/undo
    assert "presenter_move1#2" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    presenter/redo
    presenter/sel-expr 2
    presenter/up-expr
    assert "presenter_move1#3" [ presenter/expr-stack-debug ] [ "3 = 3" "1 = 1" "2 = 2" ]
    presenter/undo
    assert "presenter_move1#4" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "2 = 2" ]
    presenter/redo
    presenter/sel-expr 1
    presenter/up-expr
    assert "presenter_move1#5" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    presenter/sel-expr 0
    presenter/down-expr
    assert "presenter_move1#6" [ presenter/expr-stack-debug ] [ "3 = 3" "1 = 1" "2 = 2" ]
    presenter/undo
    assert "presenter_move1#7" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    presenter/redo
    presenter/down-expr
    assert "presenter_move1#8" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "2 = 2" ]
    presenter/down-expr
    assert "presenter_move1#9" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    presenter/sel-expr 2
    presenter/down-expr
    assert "presenter_move1#10" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "2 = 2" ]
    presenter/down-expr
    assert "presenter_move1#11" [ presenter/expr-stack-debug ] [ "2 = 2" "1 = 1" "3 = 3" ]
    presenter/sel-expr 3
    presenter/down-expr
    assert "presenter_move1#12" [ presenter/expr-stack-debug ] [ "3 = 3" "2 = 2" "1 = 1" ]
    presenter/undo
    presenter/redo
    assert "presenter_move1#13" [ presenter/expr-stack-debug ] [ "3 = 3" "2 = 2" "1 = 1" ]

    ; move2 : pull-expr push-expr
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'n3
    presenter/enter
    presenter/sel-expr 0
    presenter/pull-expr 
    assert "presenter_move2#1" [ presenter/expr-stack-debug ] [ "2 = 2" "3 = 3" "1 = 1" ]
    assert "presenter_move2#2" [ presenter/expr-index ] 3
    presenter/undo
    assert "presenter_move2#3" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    assert "presenter_move2#4" [ presenter/expr-index ] 0
    presenter/sel-expr 2
    presenter/pull-expr
    assert "presenter_move2#5" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "2 = 2" ]
    assert "presenter_move2#6" [ presenter/expr-index ] 3
    presenter/undo
    presenter/sel-expr 0
    assert "presenter_move2#7" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]
    presenter/push-expr
    assert "presenter_move2_expr#8" [ presenter/expr-stack-debug ] [ "3 = 3" "1 = 1" "2 = 2" ]
    assert "presenter_move2_expr#9" [ presenter/expr-index ] 1
    presenter/undo
    presenter/sel-expr 2
    presenter/push-expr
    assert "presenter_move2#10" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "2 = 2" ]
    assert "presenter_move2#11" [ presenter/expr-index ] 2
    presenter/undo
    assert "presenter_move2#12" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" ]

    ; roll
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'n3
    presenter/enter
    presenter/push-key 'n4
    presenter/enter
    presenter/roll-clockwise 
    assert "presenter_roll#1" [ presenter/expr-stack-debug ] [ "4 = 4" "1 = 1" "2 = 2" "3 = 3" ]
    presenter/roll-clockwise 
    assert "presenter_roll#2" [ presenter/expr-stack-debug ] [ "3 = 3" "4 = 4" "1 = 1" "2 = 2" ]
    presenter/undo
    presenter/undo
    assert "presenter_roll#3" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]
    presenter/sel-expr 2
    presenter/roll-clockwise
    assert "presenter_roll#4" [ presenter/expr-stack-debug ] [ "1 = 1" "4 = 4" "2 = 2" "3 = 3" ]
    presenter/undo
    assert "presenter_roll#5" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]
    presenter/sel-expr 0
    presenter/roll-anticlockwise
    presenter/roll-anticlockwise
    assert "presenter_roll#6" [ presenter/expr-stack-debug ] [ "3 = 3" "4 = 4" "1 = 1" "2 = 2" ]
    presenter/undo
    presenter/undo
    assert "presenter_roll#7" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]
    presenter/sel-expr 2
    presenter/roll-anticlockwise
    assert "presenter_roll#8" [ presenter/expr-stack-debug ] [ "1 = 1" "3 = 3" "4 = 4" "2 = 2"]
    presenter/undo
    assert "presenter_roll#9" [ presenter/expr-stack-debug ] [ "1 = 1" "2 = 2" "3 = 3" "4 = 4" ]

    ; troubleshooting
    presenter/reset
    presenter/push-key 'paren-l
    presenter/push-key 'n1
    presenter/push-key 'n2
    assert "presenter_trouble#1" [ presenter/failed-as-string ] "(12"
    presenter/backspace
    assert "presenter_trouble#2" [ presenter/failed-as-string ] "(1"
    presenter/reset
    presenter/push-key 'n1
    presenter/enter
    presenter/push-key 'n2
    presenter/enter
    presenter/push-key 'add
    presenter/load-expr
    presenter/backspace
    assert "presenter_trouble#3" [ presenter/expr-debug-string ] "(1) [ +(2 ] = 1"
    assert "presenter_trouble#4" [ presenter/expr-stack-debug ] [ "(1) + (2) = 3" ]
    presenter/backspace
    presenter/push-key 'n3
    presenter/push-key 'paren-r
    presenter/enter
    assert "presenter_trouble#5" [ presenter/expr-debug-string ] ""
    assert "presenter_trouble#6" [ presenter/expr-stack-debug ] [ "(1) + (3) = 4" ]
    

    print "Test-presenter done"
]
;test-presenter
;]

]
;recalculator-test

; Use immediately as it's still hot
recalculator-test/run

