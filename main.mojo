from hashtable import dict, HashableStr, CollectionElement
from builtin.string import atol
from math.limit import inf, neginf
from math import copysign
from algorithm import vectorize, parallelize, unroll

alias MAX_TEMP = inf[DType.float64]()
alias MIN_TEMP = neginf[DType.float64]()
alias DATA_PATH = String("./data/1mln_measurements.txt")
alias N_CHUNKS = 10
alias FILE_SIZE_ESTIMATION = 1_000_000 # rough estimation of bytes we want to read

@always_inline
fn s2f(s: String) raises -> Float64:
    for i in range(len(s)):
        if s[i] == ".":
            var res: Float64 = atol(s[0:i])            
            res += copysign(atol(s[i+1:]) / (10**len(s[i+1:])), res)                        
            return res
    return MIN_TEMP

fn test_s2f() raises:
    print(s2f(String("14.23")))
    print(s2f(String("-14.23")))
    print(s2f(String("0.23")))
    print(s2f(String("14.0")))
    print(s2f(String("-0.23")))

@value
@register_passable("trivial")
struct CityStats(CollectionElement):
    var min: Float64
    var max: Float64
    var sum: Float64
    var n: Int

    fn update(inout self, val: Float64):
        self.min = math.min(self.min, val)
        self.max = math.max(self.max, val)
        self.sum += val
        self.n += 1

    fn merge(inout self, other: Self):
        self.min = math.min(self.min, other.min)
        self.max = math.max(self.max, other.max)
        self.sum += other.sum
        self.n += other.n


@always_inline
fn read_file(bounds: DynamicVector[Int], inout res: DynamicVector[dict[HashableStr, CityStats]]) -> Bool:        
    @parameter
    fn read_chunk(bound_idx: Int):
        var key = HashableStr("")
        var val = String("") 
        try:
            var f = open(DATA_PATH, "rb")
            var l: Int = 0
            var r = bounds[bound_idx]
            if bound_idx > 0:
                l = bounds[bound_idx-1]
            var i = 0
            if l > 0:
                f.seek(l)
                # the idea is simple - we start reading chunk only from the begining of the row
                while True:
                    i += 1
                    let c = f.read(1)
                    if (ord(c) == 10) or (ord(c) == 0):
                        break                    
            var parsing_key = True
            while True:
                i += 1
                let c = f.read(1)
                if ord(c) == 0:
                    f.close()
                    return
                if parsing_key:
                    if (c != ";"):
                        key.value += c
                    else:
                        parsing_key = False
                else:
                    if ord(c) != 10:
                        val += c
                    else:
                        parsing_key = True
                        var current_state = res[bound_idx].get(key, CityStats(MAX_TEMP, MIN_TEMP, 0,0))
                        current_state.update(s2f(val))
                        res[bound_idx][key] = current_state
                        if l+i > r: # read till the end of the chunk + nearest end of line
                            break
                        key = String("")
                        val = String("")
        except e:
            print(e)            
    parallelize[read_chunk](len(bounds))
    return True




fn main() raises:
    var bounds = DynamicVector[Int]()
    for i in range(1, N_CHUNKS+1):
        bounds.append(math.round(FILE_SIZE_ESTIMATION / N_CHUNKS * i).to_int())
    bounds.append(FILE_SIZE_ESTIMATION*2)    
    var res = DynamicVector[dict[HashableStr, CityStats]]()
    for i in range(len(bounds)):        
        res.append(dict[HashableStr, CityStats]())
    read_file(bounds, res)

    # collect results to the single dict
    var final_res = dict[HashableStr, CityStats]()
    for bound in range(len(res)):
        for row in res[bound].items():            
            var current_state = final_res.get(row.key, CityStats(MAX_TEMP, MIN_TEMP, 0,0))
            current_state.merge(row.value)
            final_res[row.key] = current_state
    
    var total_n = 0
    for city in final_res.items():
        #print(city.key, city.value.min, city.value.max, city.value.sum / city.value.n, city.value.n)
        total_n += city.value.n
    print(total_n)