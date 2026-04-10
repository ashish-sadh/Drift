# Synthetic Query Data — Intent Classification Training

## Intent Categories

| Intent | SubIntent | Example |
|--------|-----------|---------|
| `food_log` | `single` | "log 2 eggs" |
| `food_log` | `multi` | "had rice, dal, and roti" |
| `food_log` | `meal` | "log breakfast" (asks what you had) |
| `food_log` | `quick_cal` | "log 500 cal for lunch" |
| `food_log` | `with_macros` | "log 400 cal 30g protein" |
| `food_query` | `status` | "how am I doing" |
| `food_query` | `calories_left` | "calories left" |
| `food_query` | `lookup` | "calories in samosa" |
| `food_query` | `suggest` | "what should I eat" |
| `food_query` | `yesterday` | "what did I eat yesterday" |
| `food_query` | `weekly` | "weekly summary" |
| `food_edit` | `delete` | "delete last entry" |
| `food_edit` | `undo` | "undo" |
| `weight_log` | `log` | "I weigh 165 lbs" |
| `weight_query` | `trend` | "how's my weight" |
| `weight_query` | `progress` | "am I losing weight" |
| `weight_edit` | `set_goal` | "set goal to 160" |
| `exercise_start` | `template` | "start push day" |
| `exercise_start` | `smart` | "surprise me with a workout" |
| `exercise_log` | `activity` | "I did yoga for 30 min" |
| `exercise_query` | `suggest` | "what should I train" |
| `exercise_query` | `history` | "workout history" |
| `health_query` | `sleep` | "how did I sleep" |
| `health_query` | `supplements` | "did I take everything" |
| `health_action` | `supplement_taken` | "took my creatine" |
| `health_action` | `body_comp` | "body fat 18" |
| `chat` | `greeting` | "hi" |
| `chat` | `thanks` | "thanks" |
| `chat` | `advice` | "how to lose fat" |

## Food Logging — Natural Variations (50+)

### Single item
1. "log 2 eggs"
2. "ate a banana"
3. "had chicken breast for lunch"
4. "I just ate a samosa"
5. "track 3 rotis"
6. "eating oatmeal"
7. "drank a latte"
8. "had some almonds"
9. "log 100g chicken"
10. "ate 200ml milk"

### Multi-item
11. "log chicken and rice"
12. "had rice, dal, and roti for dinner"
13. "I ate eggs, toast, and coffee"
14. "log breakfast with 2% milk, eggs and toast"
15. "had a salad with chicken, avocado, and feta"
16. "ate paneer tikka with naan and raita"

### Natural/conversational
17. "can you help me log my lunch"
18. "I had a big lunch — biryani and raita"
19. "just finished eating — chicken sandwich and fries"
20. "I ate out at Chipotle, had a burrito bowl"
21. "snacked on some trail mix around 3pm"
22. "grabbed a coffee and a muffin"
23. "had leftover dal for lunch"
24. "I made a smoothie with banana and spinach"

### With amounts/units
25. "log 200g paneer tikka"
26. "had 2 slices of pizza"
27. "ate half an avocado"
28. "log 1.5 cups of rice"
29. "had 3 pieces of chicken"
30. "ate a couple of eggs"
31. "had a bowl of oatmeal"
32. "2 to 3 bananas"

### Meal-level
33. "log lunch"
34. "log dinner"
35. "what did I have for breakfast — rice and eggs"
36. "log my breakfast"
37. "I need to log what I ate"

### Quick-add
38. "log 500 cal"
39. "log 400 calories for lunch"
40. "log 400 cal 30g protein lunch"
41. "just add 300 cal for a snack"

## Food Queries (20+)
42. "how am I doing"
43. "how are you doing"  (means "how am I doing" in health context)
44. "calories left"
45. "how many calories left"
46. "what should I eat for dinner"
47. "calories in samosa"
48. "estimate calories for biryani"
49. "how's my protein"
50. "what about carbs"
51. "daily summary"
52. "yesterday"
53. "weekly summary"
54. "compare this week to last"
55. "what did I eat today"
56. "food ideas"
57. "suggest me something healthy"
58. "am I on track"
59. "why am I not losing weight"
60. "how much have I lost"

## Exercise (15+)
61. "start push day"
62. "start chest workout"
63. "begin leg day"
64. "let's do upper body"
65. "surprise me with a workout"
66. "coach me today"
67. "what should I train"
68. "I did yoga for 30 min"
69. "I ran 3 miles"
70. "just finished 20 min cardio"
71. "I did yoga for like half an hour"
72. "workout history"
73. "how many workouts this week"
74. "log exercise"

## Health (10+)
75. "how did I sleep"
76. "sleep trend"
77. "sleep quality last week"
78. "did I take my supplements"
79. "took my creatine"
80. "took vitamin D and fish oil"
81. "body fat 18"
82. "bmi 24"
83. "what's my TDEE"
84. "explain calories"

## Weight (10+)
85. "I weigh 165 lbs"
86. "weight is 75.2 kg"
87. "scale says 82 kg"
88. "set goal to 160 lbs"
89. "set my goal to one sixty"
90. "how's my weight"
91. "am I losing weight"
92. "weight progress"

## Chat/Meta (10+)
93. "hi"
94. "hello"
95. "thanks"
96. "ok"
97. "how to lose fat"
98. "what's a good diet"
99. "scan barcode"
100. "undo"
101. "delete last entry"
102. "remove the rice"
103. "copy yesterday"

## Edge Cases / Hard Queries (20+)
104. "I had the same thing as yesterday for breakfast"
105. "log what I had last Monday"
106. "I had a PBJ sandwich"
107. "had some shredded chicken"
108. "I ate at Sweetgreen — the harvest bowl"
109. "200 of that paneer biryani"
110. "actually I didn't eat that, I had eggs instead"
111. "I had a plate of rice with dal and chicken on the side"
112. "log the healthy version of samosa"
113. "I went to the gym" (not an activity — means start workout)
114. "how much protein in chicken vs paneer"
115. "should I eat before or after workout"
116. "I'm full, stop logging"
117. "never mind"
118. "what's in my last meal"
119. "repeat what I had for lunch yesterday"
120. "I had 2 eggs and a coffee, then later a sandwich"
