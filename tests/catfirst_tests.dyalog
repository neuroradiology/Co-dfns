﻿:Namespace catfirst

S←':Namespace' 'Run←{⍺⍪⍵}' ':EndNamespace'

'01'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(⍬)           (⍬)
'02'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(5)           (5)
'03'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(⍬)           (5)
'04'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(⍬)           (⍳5)
'05'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(⍳7)          (⍳5)
'06'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(5)           (⍳5)
'07'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(2 2⍴5)       (2 2⍴5)
'08'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(2 2 3⍴5)     (2 3⍴5)
'09'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(2 3⍴5)       (2 2 3⍴⌽⍳12)
'10'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(2 3⍴5)       (2 2 3⍴5)
'11'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(5)           (2 2⍴5)
'12'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(,5 5)        (2 2⍴5)
'13'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(,5)          (,5)
'14'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(7⍴1 0)       (2 7⍴0 1)
'15'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(,5 4)        (2 2⍴1 0 0)
'16'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(2 2⍴1 0 0)   (,5 4)
'17'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(10 10⍴⌽⍳100) (3 10⍴-⌽⍳30)
'18'('catfirst' S 'Run' #.util.GEN∆T2 ⎕THIS)(3 10⍴-⌽⍳30)  (10 10⍴⌽⍳100)

:EndNamespace
