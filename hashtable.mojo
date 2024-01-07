from memory import memset_zero, memcpy
from sys.info import sizeof

alias EMPTY_BUCKET = -1

from collections.vector import DynamicVector


struct ListIter[T: CollectionElement]:
    var data: list[T]
    var idx: Int

    fn __init__(inout self, data: list[T]):
        self.idx = -1
        self.data = data

    fn __len__(self) -> Int:
        return len(self.data) - self.idx - 1

    fn __next__(inout self) raises -> T:
        self.idx += 1
        return self.data[self.idx]


@value
struct list[T: CollectionElement](Sized, Movable):
    var _internal_vector: DynamicVector[T]

    fn __init__(inout self):
        self._internal_vector = DynamicVector[T]()

    fn __init__(inout self, owned value: DynamicVector[T]):
        self._internal_vector = value

    @always_inline
    fn _normalize_index(self, index: Int) -> Int:
        if index < 0:
            return len(self) + index
        else:
            return index

    fn append(inout self, value: T):
        self._internal_vector.push_back(value)

    fn clear(inout self):
        self._internal_vector.clear()

    fn copy(self) -> list[T]:
        return list(self._internal_vector)

    fn extend(inout self, other: list[T]):
        for i in range(len(other)):
            self.append(other.unchecked_get(i))

    fn pop(inout self, index: Int = -1) raises -> T:
        if index >= len(self._internal_vector):
            raise Error("list index out of range")
        let new_index = self._normalize_index(index)
        let element = self.unchecked_get(new_index)
        for i in range(new_index, len(self) - 1):
            self[i] = self[i + 1]
        self._internal_vector.resize(len(self._internal_vector) - 1, element)
        return element

    fn reverse(inout self) raises:
        for i in range(len(self) // 2):
            let mirror_i = len(self) - 1 - i
            let tmp = self[i]
            self[i] = self[mirror_i]
            self[mirror_i] = tmp

    fn insert(inout self, key: Int, value: T) raises:
        let index = self._normalize_index(key)
        if index >= len(self):
            self.append(value)
            return
        # we increase the size of the array before insertion
        self.append(self[-1])
        for i in range(len(self) - 2, index, -1):
            self[i] = self[i - 1]
        self[key] = value

    fn __getitem__(self, index: Int) raises -> T:
        if index >= len(self._internal_vector):
            raise Error("list index out of range")
        return self.unchecked_get(self._normalize_index(index))

    fn __getitem__(self: Self, limits: slice) raises -> Self:
        var new_list: Self = Self()
        for i in range(limits.start, limits.end, limits.step):
            new_list.append(self[i])
        return new_list

    @always_inline
    fn unchecked_get(self, index: Int) -> T:
        return self._internal_vector[index]

    fn __setitem__(inout self, key: Int, value: T) raises:
        if key >= len(self._internal_vector):
            raise Error("list index out of range")
        self.unchecked_set(self._normalize_index(key), value)

    @always_inline
    fn unchecked_set(inout self, key: Int, value: T):
        self._internal_vector[key] = value

    @always_inline
    fn __len__(self) -> Int:
        return len(self._internal_vector)

    fn __iter__(self: Self) -> ListIter[T]:
        return ListIter(self)

    @staticmethod
    fn from_string(input_value: String) -> list[String]:
        var result = list[String]()
        for i in range(len(input_value)):
            result.append(input_value[i])
        return result


fn list_to_str(input_list: list[String]) raises -> String:
    var result: String = "["
    for i in range(len(input_list)):
        let repr = "'" + str(input_list[i]) + "'"
        if i != len(input_list) - 1:
            result += repr + ", "
        else:
            result += repr
    return result + "]"


fn list_to_str(input_list: list[Int]) raises -> String:
    var result: String = "["
    for i in range(len(input_list)):
        let repr = str(input_list.__getitem__(index=i))
        if i != len(input_list) - 1:
            result += repr + ", "
        else:
            result += repr
    return result + "]"


trait Equalable:
    fn __eq__(self: Self, other: Self) -> Bool:
        ...


trait Hashable(Equalable):
    fn __hash__(inout self) -> Int:
        ...


fn hash[T: Hashable](inout x: T) -> Int:
    return x.__hash__()


fn hash(x: Int) -> Int:
    return x


fn hash(x: Int64) -> Int:
    """We assume 64 bits here, which is a big assumption.
    TODO: Make it work for 32 bits.
    """
    return hash(x.to_int())


fn hash(x: String) -> Int:
    """Very simple hash function."""
    let prime = 31
    var hash_value = 0
    for i in range(len(x)):
        hash_value = prime * hash_value + ord(x[i])
    return hash_value


trait HashableCollectionElement(CollectionElement, Hashable):
    pass




@value
struct CustomBool(CollectionElement):
    var value: Bool

    fn __init__(inout self, value: Bool):
        self.value = value

    fn __bool__(self) -> Bool:
        return self.value


@value
struct HashableInt(HashableCollectionElement, Intable):
    var value: Int

    fn __init__(inout self, value: Int):
        self.value = value

    fn __hash__(inout self) -> Int:
        return hash(self.value)

    fn __eq__(self, other: HashableInt) -> Bool:
        return self.value == other.value

    fn __int__(self) -> Int:
        return self.value


@value
struct HashableStr(HashableCollectionElement, Stringable):
    var value: String

    fn __init__(inout self, value: StringLiteral):
        self.value = value
        

    fn __init__(inout self, value: String):
        self.value = value  
        

    fn __hash__(inout self) -> Int:        
        return hash(self.value)

    fn __eq__(self, other: HashableStr) -> Bool:
        return self.value == other.value

    fn __str__(self) -> String:
        return self.value


@value
struct dict[K: HashableCollectionElement, V: CollectionElement](Sized, CollectionElement):
    var _keys: list[K]
    var _values: list[V]
    var _key_map: list[Int]
    var _deleted_mask: list[CustomBool]
    var _count: Int
    var _capacity: Int

    fn __init__(inout self):
        self._count = 0
        self._capacity = 16
        self._keys = list[K]()
        self._values = list[V]()
        self._key_map = list[Int]()
        self._deleted_mask = list[CustomBool]()
        self._initialize_key_map(self._capacity)

    fn __setitem__(inout self, inout key: K, value: V):
        if self._count / self._capacity >= 0.8:
            self._rehash()

        self._put(key, value, -1)

    fn _initialize_key_map(inout self, size: Int):
        self._key_map.clear()
        for i in range(size):
            self._key_map.append(EMPTY_BUCKET)  # -1 means unused

    fn _rehash(inout self):
        let old_mask_capacity = self._capacity
        self._capacity *= 2
        self._initialize_key_map(self._capacity)

        for i in range(len(self._keys)):
            self._put(i)

    fn _put(inout self, rehash_index: Int):
        var key = self._keys.unchecked_get(rehash_index)
        var value = self._values.unchecked_get(rehash_index)
        self._put(key,value, rehash_index)

    fn _put(inout self, inout key: K, value: V, rehash_index: Int):
        let key_hash = hash(key)
        let modulo_mask = self._capacity
        var key_map_index = key_hash % modulo_mask
        while True:
            let key_index = self._key_map.unchecked_get(index=key_map_index)
            if key_index == EMPTY_BUCKET:
                let new_key_index: Int
                if rehash_index == -1:
                    self._keys.append(key)
                    self._values.append(value)
                    self._deleted_mask.append(False)
                    self._count += 1
                    new_key_index = len(self._keys) - 1
                else:
                    new_key_index = rehash_index
                self._key_map.unchecked_set(key_map_index, new_key_index)
                return

            let existing_key = self._keys.unchecked_get(key_index)
            if existing_key == key:
                self._values.unchecked_set(key_index, value)
                if self._deleted_mask.unchecked_get(key_index).value:
                    self._count += 1
                    self._deleted_mask.unchecked_set(key_index, False)
                return

            key_map_index = (key_map_index + 1) % modulo_mask

    fn __getitem__(self, inout key: K) raises -> V:
        let key_hash = hash(key)
        let modulo_mask = self._capacity
        var key_map_index = key_hash % modulo_mask
        while True:
            let key_index = self._key_map.__getitem__(index=key_map_index)
            if key_index == EMPTY_BUCKET:
                raise Error("Key not found")
            let other_key = self._keys.unchecked_get(key_index)
            if other_key == key:
                if self._deleted_mask[key_index]:
                    raise Error("Key not found")
                return self._values[key_index]
            key_map_index = (key_map_index + 1) % modulo_mask

    fn get(self, inout key: K, default: V) -> V:
        try:
            return self[key]
        except Error:            
            return default

    fn pop(inout self, inout key: K) raises:
        let key_hash = hash(key)
        let modulo_mask = self._capacity
        var key_map_index = key_hash % modulo_mask
        while True:
            let key_index = self._key_map.__getitem__(index=key_map_index)
            if key_index == EMPTY_BUCKET:
                raise Error("KeyError, key not found.")
            let other_key = self._keys.unchecked_get(key_index)
            if other_key == key:
                self._count -= 1
                self._deleted_mask[key_index] = True
                return
            key_map_index = (key_map_index + 1) % modulo_mask

    fn __len__(self) -> Int:
        return self._count

    fn items(self) -> KeyValueIterator[K, V]:
        return KeyValueIterator(self)


@value
struct Pair[K: HashableCollectionElement, V: CollectionElement]:
    var key: K
    var value: V


@value
struct KeyValueIterator[K: HashableCollectionElement, V: CollectionElement]:
    var _dict: dict[K, V]
    var idx: Int
    var elements_seen: Int

    fn __init__(inout self, dict_: dict[K, V]):
        self.idx = -1
        self.elements_seen = 0
        self._dict = dict_

    fn __len__(self) -> Int:
        return len(self._dict) - self.elements_seen

    fn __next__(inout self) -> Pair[K, V]:
        self.idx += 1
        while self.idx < len(self._dict._deleted_mask):
            if self._dict._deleted_mask.unchecked_get(self.idx):
                self.idx += 1
                continue
            self.elements_seen += 1
            break
        return Pair(
            self._dict._keys.unchecked_get(self.idx),
            self._dict._values.unchecked_get(self.idx),
        )

    fn __iter__(self) -> KeyValueIterator[K, V]:
        return self