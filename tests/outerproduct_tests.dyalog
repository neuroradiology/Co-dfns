﻿:Namespace outerproduct

S←':Namespace' 'R1←{⍺∘.×⍵}' 'R2←{⍺∘.{⍺×⍵}⍵}' ':EndNamespace'

'01'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(1)            (1)
'02'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(1)            (⍬)
'03'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(⍬)        (⍬)
'04'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(⍬)        (1+⍳3)
'05'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(1+⍳3)     (⍬)
'06'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(5)            (1+⍳3)
'07'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(1+⍳3)     (1+⍳3)
'08'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(2 2⍴3)    (1+⍳7)
'09'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(2 2⍴1+⍳4) (2 2⍴1+⍳4)
'10'('outerproduct' S 'R1' #.util.GEN∆T2 ⎕THIS)(2 2⍴1+⍳4) (2 2⍴÷1+⍳4)
'11'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(1)            (1)
'12'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(1)            (⍬)
'13'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(⍬)        (⍬)
'14'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(⍬)        (1+⍳3)
'15'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(1+⍳3)     (⍬)
'16'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(5)            (1+⍳3)
'17'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(1+⍳3)     (1+⍳3)
'18'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(2 2⍴3)    (1+⍳7)
'19'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(2 2⍴1+⍳4) (2 2⍴1+⍳4)
'20'('outerproduct' S 'R2' #.util.GEN∆T2 ⎕THIS)(2 2⍴1+⍳4) (2 2⍴÷1+⍳4)

:EndNamespace

