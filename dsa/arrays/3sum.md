# 3Sum

## 1. Problem Summary

**Problem:** Given an integer array `nums`, return all unique triplets
`[nums[i], nums[j], nums[k]]` such that:

- `i != j`
- `j != k`
- `i != k`
- `nums[i] + nums[j] + nums[k] === 0`

The result must not contain duplicate triplets.

**Example**

Input:

```javascript
nums = [-1, 0, 1, 2, -1, -4];
```

Output:

```javascript
[
  [-1, -1, 2],
  [-1, 0, 1],
];
```

**Important:** The order of triplets in the result does not matter.

---

## 2. Pattern Recognition

**Primary pattern:** Sorting + Two Pointers

### Recognition signals

- We need to find three elements satisfying a target sum.
- The array can contain duplicates.
- We must return unique combinations.
- Sorting allows us to reason about values and move pointers intelligently.

### Core idea

Reduce the 3Sum problem to repeated Two Sum problems.

1. Sort the array.
2. Fix one element at index `i`.
3. Find two other elements whose sum is `-nums[i]`.
4. Use two pointers to find the remaining pair.
5. Skip duplicates to avoid repeated triplets.

---

## 3. Brute-Force Approach

Try every possible triplet using three nested loops.

```javascript
function threeSumBruteForce(nums) {
  const result = [];
  const seen = new Set();

  for (let i = 0; i < nums.length - 2; i++) {
    for (let j = i + 1; j < nums.length - 1; j++) {
      for (let k = j + 1; k < nums.length; k++) {
        if (nums[i] + nums[j] + nums[k] === 0) {
          const triplet = [nums[i], nums[j], nums[k]].sort((a, b) => a - b);

          const key = triplet.join(",");

          if (!seen.has(key)) {
            seen.add(key);
            result.push(triplet);
          }
        }
      }
    }
  }

  return result;
}
```

### Complexity

- Time: O(n³) for enumerating triplets, plus triplet normalization and set operations.
- Auxiliary space: O(u) for storing unique triplets and their keys, where `u` is the number of unique triplets found.

### Limitation

We repeatedly examine combinations that cannot produce new answers.
We need a way to reduce the search space.

---

## 4. Optimized Approach

### Step 1: Sort the array

For the example:

```text
Original: [-1, 0, 1, 2, -1, -4]
Sorted:   [-4, -1, -1, 0, 1, 2]
```

Sorting gives us a useful property:

- If the current sum is too small, increase it by moving the left pointer right.
- If the current sum is too large, decrease it by moving the right pointer left.

### Step 2: Fix one element

For every index `i`, treat `nums[i]` as the first element of the triplet.

We now need:

```text
nums[left] + nums[right] = -nums[i]
```

### Step 3: Apply two pointers

Initialize:

```javascript
let left = i + 1;
let right = nums.length - 1;
```

Calculate:

```javascript
const sum = nums[i] + nums[left] + nums[right];
```

- If `sum === 0`: record the triplet and move both pointers.
- If `sum < 0`: move `left` right to increase the sum.
- If `sum > 0`: move `right` left to decrease the sum.

### Step 4: Skip duplicates

We must avoid duplicate triplets.

- Skip repeated values at the fixed index `i`.
- After finding a valid triplet, skip repeated values at both pointers.

---

## 5. Optimized JavaScript Solution

```javascript
function threeSum(nums) {
  nums.sort((a, b) => a - b);

  const result = [];
  const n = nums.length;

  for (let i = 0; i < n - 2; i++) {
    // Skip duplicate fixed elements.
    if (i > 0 && nums[i] === nums[i - 1]) {
      continue;
    }

    // All remaining values are >= nums[i].
    // If nums[i] is positive, the sum cannot be zero.
    if (nums[i] > 0) {
      break;
    }

    let left = i + 1;
    let right = n - 1;

    while (left < right) {
      const sum = nums[i] + nums[left] + nums[right];

      if (sum === 0) {
        result.push([nums[i], nums[left], nums[right]]);

        left++;
        right--;

        // Skip duplicate left values.
        while (left < right && nums[left] === nums[left - 1]) {
          left++;
        }

        // Skip duplicate right values.
        while (left < right && nums[right] === nums[right + 1]) {
          right--;
        }
      } else if (sum < 0) {
        left++;
      } else {
        right--;
      }
    }
  }

  return result;
}
```

---

## 6. Dry Run

Input:

```javascript
[-1, 0, 1, 2, -1, -4];
```

After sorting:

```text
[-4, -1, -1, 0, 1, 2]
```

### Iteration 1: i = 0

```text
nums[i] = -4
left = 1, right = 5

-4 + (-1) + 2 = -3
```

The sum is negative, so move `left` right.

Continue moving pointers until they meet. No valid triplet is found for `-4`.

### Iteration 2: i = 1

```text
nums[i] = -1
left = 2, right = 5
```

| Fixed | Left | Right | Sum | Action             |
| ----: | ---: | ----: | --: | ------------------ |
|    -1 |   -1 |     2 |   0 | Record `[-1,-1,2]` |
|    -1 |    0 |     1 |   0 | Record `[-1,0,1]`  |

The pointers then cross, ending this search.

### Iteration 3: i = 2

```text
nums[i] = -1
```

This is a duplicate of the previous fixed value. Skip it.

### Iteration 4: i = 3

```text
nums[i] = 0
```

No additional valid triplets are found.

### Final output

```javascript
[
  [-1, -1, 2],
  [-1, 0, 1],
];
```

---

## 7. Complexity Analysis

Let `n` be the length of the input array.

### Time complexity: O(n²)

- Sorting takes O(n log n).
- The outer loop runs O(n) times.
- For each fixed element, the two pointers move across the array in O(n) time.
- Total: O(n log n + n²) = **O(n²)**.

### Auxiliary space

- The two-pointer search uses O(1) additional space, excluding the sort implementation and output.
- JavaScript's sorting implementation may use implementation-dependent auxiliary space.
- The returned triplets require O(u) output space, where `u` is the number of unique triplets.

---

## 8. Why Does This Algorithm Work?

### Correctness intuition

After sorting, fixing an element reduces the remaining problem to finding two values that sum to its negation.

For each pair of pointers:

- If the sum is too small, moving the right pointer left would not increase it. Moving the left pointer right is the useful direction.
- If the sum is too large, moving the left pointer right would not decrease it. Moving the right pointer left is the useful direction.
- If the sum is zero, we have found a valid triplet.

Because the array is sorted, these movements safely eliminate pairs that cannot work for the current pointer position.

Duplicate skipping prevents the same value combination from being recorded repeatedly.

Therefore, the algorithm finds all unique zero-sum triplets.

---

## 9. Edge Cases

| Input                   | Expected output             |
| ----------------------- | --------------------------- |
| `[]`                    | `[]`                        |
| `[0]`                   | `[]`                        |
| `[0, 0]`                | `[]`                        |
| `[0, 0, 0]`             | `[[0, 0, 0]]`               |
| `[0, 0, 0, 0]`          | `[[0, 0, 0]]`               |
| `[1, 2, -2, -1]`        | `[]`                        |
| `[-1, 0, 1, 2, -1, -4]` | `[[-1, -1, 2], [-1, 0, 1]]` |

---

## 10. Common Mistakes

1. Forgetting to sort before applying the two-pointer technique.
2. Using `nums.sort()` without a numeric comparator in JavaScript.
3. Skipping duplicates before recording a valid triplet in a way that accidentally misses solutions.
4. Moving only one pointer after finding a valid triplet without handling duplicates.
5. Returning duplicate triplets.
6. Claiming O(n) time because the inner loop uses two pointers; the outer loop makes the total O(n²).
7. Forgetting that `nums.sort()` mutates the original array.

---

## 11. Interview Explanation (60–120 Seconds)

"I would first consider a brute-force solution using three nested loops, which takes O(n³) time.

To optimize it, I sort the array and fix one element. The remaining task is to find two numbers whose sum is the negative of the fixed element.

I use two pointers: one immediately after the fixed index and one at the end of the array. If the sum is too small, I move the left pointer forward. If it is too large, I move the right pointer backward. If the sum is zero, I record the triplet and move both pointers.

Since duplicates are allowed in the input but not in the output, I skip repeated fixed values and repeated pointer values after finding a valid triplet.

Sorting takes O(n log n), and the outer loop with the two-pointer search takes O(n²), so the overall time complexity is O(n²)."

---

## 12. Variations to Explore

- 2Sum: Find a pair that adds up to a target.
- 3Sum Closest: Find a triplet whose sum is closest to a target.
- 4Sum: Find unique quadruplets that add up to a target.
- 3Sum Smaller: Count triplets whose sum is less than a target.
- Two Sum II: Find a pair in a sorted array.

---

## 13. Revision Checklist

- [ ] Can I identify why sorting enables two pointers?
- [ ] Can I derive the optimized solution without looking at the code?
- [ ] Can I explain why each pointer movement is safe?
- [ ] Can I handle duplicate triplets correctly?
- [ ] Can I implement the solution independently?
- [ ] Can I explain O(n²) time complexity?
- [ ] Can I solve a related variation?

### Revision Log

- First solve date:
- Day 1 review:
- Day 3 review:
- Day 7 review:
- Day 14 review:
- Day 30 review:
- Confidence (1–5):
- Needed hints?:
- Main mistake:
- Next review date:
