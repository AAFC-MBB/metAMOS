[ReadDenoiser]
g 5
k 17
LD 0
GS 4000000
NodeCovTh 2
EdgeCovTh 1
CorrTh 5
CovTh 5

[ReadDenoiserStep2]
g 15
k 31
LD 0
GS 4000000
NodeCovTh 2
EdgeCovTh 1
#CorrTh 5
#CovTh 5
CorrTh 1
CovTh 1

[SparseAssembler]
g 10
LD 0
GS 2000000
NodeCovTh 1
EdgeCovTh 0
BFS 1
PathCovTh 5
ResolveBranchesPE 1
LinkCovTh 1
