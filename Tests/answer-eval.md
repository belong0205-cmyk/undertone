# Answer evaluation — manual check for TESTER

128 common kitchen-interview and assessment questions (including follow-ups, Australian food safety and WHS, and SA Cook questionnaire topics) with an ideal answer and what must (not) happen. The ideal answer is one good
version; other wording passes if it meets every rule below.

## Setup
1. Build and open the app. On the Hồ sơ page import `Tests/eval-profile.undertone-profile` (double-click it or use
   Import) and make "Minh Le" the active profile. It is an imaginary person; its menu has the same shape as real menus:
   Vietnamese set meals on a 2-week rotation (Monday–Saturday) plus a European set menu by weekday, written in Vietnamese.
2. Start listening, then speak each question through the speakers from Terminal, for example:
   `say -v Karen "What do you have in your menu?"` (Karen is an Australian voice). For split questions (section E) run
   the two `say` commands with `sleep 2` between them.
3. Write down today's weekday before section A (questions 5 and 10 depend on it).

## Pass rules (every answer)
1. Answers the question that was asked, at the same scope: a general question gets a general answer (big picture +
   at most 2–3 examples), a specific question gets exactly that detail.
2. No invented facts: no day, date, week, time, number, price or name that was not asked for or is not in the profile /
   knowledge base. Missing fixed personal facts (name, age, address, workplace, phone number) use a placeholder in
   square brackets; soft facts (hobbies, likes) get a short general answer with no brackets.
3. As short as possible but complete: the direct answer first, then one short B1 sentence per point the question asks
   for (every item, step or reason; both halves of "what and why"), nothing extra and no repeating. No fixed word or
   sentence limit. Spoken as the user ("I", "my", "we"); never "You could say…".
4. Simple B1 English; Vietnamese dishes get simple English names.
5. Menu and dish answers name European dishes first; Vietnamese dishes come after, or only when asked (user preference).
6. The Vietnamese answer says the same thing in the first person ("tôi").
7. Questions that need no reply show no answer ("-" or the filler is skipped).

## A. Menu — general vs specific
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 1 | What do you have in your menu? | We cook a European set menu, like lasagne and roast chicken. We cook Vietnamese set meals too. The menu changes every day. | Must NOT name a day (the original bug). European dishes first. |
| 2 | What kind of food do you cook? | I cook European dishes like lasagne and fish and chips. I also cook Vietnamese home-style meals. | European first; no day, no prices. |
| 3 | Tell me about your menu. | We have a European set menu with soup, a main, sides, salad and dessert. We have Vietnamese set meals too. Both change every day. | General only; European first. |
| 4 | What does one meal come with? | Our European set menu comes with soup and a main course. It also has a side, a salad and a dessert. | From the European menu header first; no invented sides. Vietnamese details only if asked. |
| 5 | What's on the menu today? | (Tuesday) Today the European menu has beef stew in red wine with mashed potato. The Vietnamese meal changes every week. | Uses today's weekday from the European menu, named first (Mon lasagne, Tue beef stew, Wed salmon, Thu spaghetti bolognese, Fri fish and chips, Sat roast chicken). Must not pick a Vietnamese week. Sunday → "No dishes are listed for Sunday." (not closed / day off). |
| 6 | What are you cooking on Friday? | On Friday we have fish and chips on the European menu. We also have a Vietnamese meal like caramelised prawns. | Friday only; European Friday = fish and chips, named first. |
| 7 | Do you have vegetarian options? | Yes, every Vietnamese set meal has a vegetarian dish, like tofu in tomato sauce. | Yes + one real example. |
| 8 | How often does your menu change? | Both menus change every day. The European one repeats every week, and the Vietnamese one every two weeks. | From the menu structure; European first. |
| 9 | What's your signature dish? | My best dishes are braised pork with eggs and sour fish soup. | From the profile's "Signature dishes" field only (Thịt kho trứng; Canh chua cá → braised pork with eggs, sour fish soup, in English); stays Vietnamese because the profile says so. Must NOT answer with a cuisine type ("European and Vietnamese food") or with the European menu, and must not say I have none yet: that sentence is right only when the field is empty. |
| 10 | What do you serve on Sunday? | No dishes are listed for Sunday. | Must not invent Sunday dishes. Must not say closed or day off, and must not name working days (rule 2cd315a: unlisted day → only "no dishes are listed"). |
| 11 | Do you serve any European food? | Yes, we have a European set menu every day. It has dishes like beef lasagne and fish and chips. | No day needed. |
| 12 | What soup do you make? | We make a different soup every day, like pumpkin soup or mushroom soup. We also make Vietnamese sour fish soup. | General, no day; European soups first. |

## B. Questions about the user — exact scope
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 13 | What's your name? | My name is Minh Le. | — |
| 14 | How old are you? | I'm 28 years old. | Age from 12 March 1998 and today (28 until 12 March 2027). |
| 15 | Where do you work? | I'm a commis chef at Green Bowl Catering. We cook set lunches for offices. | No address. |
| 16 | What time do you start work? | I start at 6 am. | Start time only. |
| 17 | What are your working hours? | I work from 6 am to 2:30 pm. | Not the opening hours. |
| 18 | When is your kitchen open? | We serve lunch from 10:30 am to 2 pm, Monday to Saturday. | Opening hours, not the user's hours. |
| 19 | How many people work in your kitchen? | There are eight people in our kitchen. | Number; roles optional only if short. |
| 20 | Tell me about your day. | I check deliveries and fridge temperatures and prep meat and vegetables. Then I cook the braised dishes and soups for lunch. | 2–3 steps, no clock times needed. |
| 21 | What are your main responsibilities? | I cook the European soups and mains and the Vietnamese braised dishes. I also check fridge temperatures. | From the profile; European first. |
| 22 | How long have you been working as a cook? | I have about three years of kitchen experience. | 3 years. |
| 23 | Do you have any certificates? | Yes, I have a Food Safety Supervisor certificate and a First Aid certificate. | Both, no invented ones. |
| 24 | What languages do you speak? | I speak Vietnamese and some English. | — |

## C. Missing personal facts → placeholder or short general answer
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 25 | What are your hobbies? | In my free time I like cooking and walking. | Hobbies are empty: a short general first-person answer. No brackets, template text, names, places or numbers. |
| 26 | What's your phone number? | My phone number is [your phone number]. | Must not invent digits. |
| 27 | Where do you live? | I live in [your suburb]. | Must not use the workplace. |

## D. Cookery knowledge (Certificate III)
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 28 | What temperature should the fridge be? | We keep the fridge at 5 °C or below. | Australian 5 °C, not 40 °F. |
| 29 | What is the temperature danger zone? | It's between 5 and 60 °C. Cold food stays at 5 or below, hot food at 60 or above. | 5–60 °C. |
| 30 | How do you cool down a big pot of soup? | I use shallow trays and an ice bath. The soup goes from 60 to 21 °C within two hours. Then it goes down to 5 °C within four more hours. | 2h/4h rule. |
| 31 | What core temperature do you cook chicken to? | I cook chicken to at least 75 °C in the thickest part. | 75 °C. |
| 32 | What's the difference between cleaning and sanitising? | Cleaning removes food, dirt and grease. Sanitising then reduces germs to a safe level with heat or chemicals. I always clean first. | Clean → sanitise; must not say sanitising kills all bacteria (FSANZ 3.2.2 cl 20). |
| 33 | What is FIFO? | FIFO means first in, first out. We use older stock first and put new stock at the back. | — |
| 34 | What are the five mother sauces? | They are béchamel, velouté, espagnole, tomato sauce and hollandaise. | All five. |
| 35 | What is a brunoise? | Brunoise is a very small dice, about 2 mm, cut from julienne. | ~2 mm. |
| 36 | How do you stop cross-contamination? | I use colour-coded boards and keep raw meat below cooked food. I wash my hands and sanitise between tasks. | — |
| 37 | A customer has a nut allergy. What do you do? | I check every ingredient, clean the bench and tools, and use separate equipment. I tell the chef and the server. | No "it's probably fine". |
| 38 | What is mise en place? | It means having everything ready before service. Ingredients are prepped, tools are ready and my station is set up. | — |
| 39 | How do you work out the food cost percentage? | I divide the food cost by the selling price without GST. Then I multiply by 100. | Ex-GST. |
| 40 | What do you use on a deep-fryer fire? | A wet chemical extinguisher or a fire blanket, never water. | Class F, no water. |

## E. Questions in pieces
| # | Pieces (about 2 s apart) | Ideal answer | Must / must not |
|---|---|---|---|
| 41 | "What do you usually…" + "cook on Fridays?" | On Fridays we cook fish and chips on the European menu. We also cook Vietnamese dishes like caramelised prawns. | Answers the joined question, once; European first. |
| 42 | "How many people…" + "work in your kitchen?" | There are eight people in our kitchen. | Not an answer to the first piece alone. |
| 43 | "Do you usually cook?" + "At your restaurant?" | Yes, I cook every day at work. I cook European soups and mains, and Vietnamese braised dishes. | One answer for both pieces; European first. |

## F. No answer expected
| # | Utterance | Expected |
|---|---|---|
| 44 | Okay. | No answer (filler). |
| 45 | Yes, chef. | No answer (filler). |
| 46 | Let's get started with the interview. | "-" (a statement, no question). |

## G. Define / Explain / List (assessor style)
Answers give the definition and every item or number asked for, not a full lesson (rule 3).
| # | Question | Ideal answer | Must / must not |
|---|---|---|---|
| 47 | Define ganache and provide common ratios for dark vs milk/white chocolate. | Ganache is chocolate melted with hot cream. For a glaze I use 1:1 dark chocolate to cream. Milk chocolate is 2:1 and white chocolate is 3:1. | Definition + ratios for all three; milk and white need more chocolate than dark. Accept truffle ratios (2:1 dark, 2.5–3:1 milk, 3–4:1 white) if the use is named. |
| 48 | What is an emulsion? Give an example. | An emulsion is oil and water mixed into tiny drops. Examples are mayonnaise and a vinaigrette. | Definition + example. |
| 49 | Explain the three types of roux. | All are equal flour and butter. White roux has no colour, blond is light golden, and brown is nut brown. | Equal weights; white / blond / brown. |
| 50 | List the five mother sauces. | Béchamel, velouté, espagnole, tomato sauce and hollandaise. | Names only, all five. |
| 51 | How do you temper dark chocolate? | I melt it to 45–50 °C and cool it to 27–28 °C. Then I warm it to 31–32 °C. | Three temperatures. |
| 52 | What is a liaison? | A liaison is egg yolks and cream. I add it at the end to thicken a sauce or soup. I never boil it after. | No boiling. |
| 53 | What's the difference between braising and stewing? | Braising cooks large pieces in a little liquid. Stewing cooks small pieces fully covered in liquid. Both are slow. | One clause each. |
| 54 | Name the three types of meringue. | French, Swiss and Italian meringue. | Names only. |
| 55 | What is the difference between crème anglaise and crème pâtissière? | Crème anglaise is a thin pouring custard I never boil. Crème pâtissière is thick, with flour, and must boil. | Anglaise no boil; pâtissière boiled. |
| 56 | What does HACCP stand for? | Hazard Analysis and Critical Control Points. It's a system to control food safety hazards at key steps. | Full name correct. |

## H. Follow-up — more detail (within about 10 s)
Ask the first question, wait for its short answer, then ask the follow-up within 10 s, e.g.
`say -v Karen "What is a roux?"; sleep 6; say -v Karen "Give me an example."`. The first answer stays short. The follow-up
answer is a few short B1 sentences in the first person, stays on the same topic, adds new facts (numbers, steps, examples)
and does not repeat the first answer.
| # | First question → short answer | Follow-up | Ideal detailed answer | Must / must not |
|---|---|---|---|---|
| 57 | What's the difference between fish and shellfish? → Fish have fins and a backbone. Shellfish have a shell, like prawns, crabs, oysters and mussels. | Can you explain more? | Fish can be round, like snapper and barramundi, or flat, like flounder. Some are white and mild, others are oily, like salmon and tuna. Shellfish are crustaceans, like prawns and crabs, or molluscs, like oysters, mussels and squid. Fresh fish has bright eyes, red gills and firm flesh. I keep all seafood on ice at 0–5 °C. I use it in one or two days. | Types of fish and shellfish + a freshness or storage fact with numbers. |
| 58 | What temperature is your fridge? → I keep it at 5 °C or below. | Why? | Bacteria grow fast between 5 and 60 °C. So cold food must stay at 5 °C or below. Some, like Listeria, still grow slowly in the fridge. So I also check use-by dates. I check and record the fridge temperature every day. | Gives the reason, not the number again. |
| 59 | What is a roux? → Equal weights of butter and flour cooked together to thicken sauces. | Give me an example. | For béchamel I make a white roux: 50 g butter and 50 g flour. I cook it for one or two minutes with no colour. Then I slowly whisk in 500 mL warm milk. That is 100 g roux per 500 mL, a coating sauce. I simmer it for about 20 minutes to cook out the flour taste. For a Mornay sauce I add cheese at the end. | A concrete example with quantities and times from the KB. |
| 60 | How do you cool a big pot of soup? → I use shallow trays and an ice bath. The soup goes from 60 to 21 °C within two hours. Then it goes down to 5 °C within four more hours. | Tell me more. | First I split the soup into shallow trays, about 5 cm deep. I put them in an ice bath or a blast chiller. I stir the soup. After two hours I probe the centre. It must be 21 °C or below. After four more hours it must be 5 °C or below. I write down each time and temperature. Then I cover it, add a date label and put it in the fridge. If the soup misses these times, I throw it out. Reheating does not make it safe. | Steps; probe after 2 h (21 °C) and 4 more h (5 °C), record; cover, date label, fridge; corrective action (throw out, not reheat). "About 5 cm deep" is correct (SFA p.41). Must not invent other check times, like every 30 minutes. |
| 61 | Define ganache and provide common ratios for dark vs milk/white chocolate. → Ganache is chocolate melted with hot cream. For a glaze I use 1:1 dark chocolate to cream. Milk chocolate is 2:1 and white chocolate is 3:1. | How do you make it? | I chop the chocolate finely. I heat the cream until it just simmers, about 80 °C. I pour the cream over the chocolate and wait one or two minutes. Then I stir from the centre until it's smooth and shiny. For a glaze I use it warm, about 32 °C. For truffles I let it set in the fridge, then roll it. | Method with temperatures. |
| 62 | What do you have on your menu? → We cook a European set menu, like lasagne and roast chicken. We cook Vietnamese set meals too. The menu changes every day. | Tell me more. | Our European set menu has a soup, a main and a side. It also has a salad and a dessert. One example is mushroom soup with beef stew in red wine. Our Vietnamese set meals come with white rice. Each has a main dish, like braised pork with eggs or caramelised prawns. It also has a stir-fry, a soup, vegetables and a dessert. There is always a vegetarian dish too, like tofu in tomato sauce. | Must give the European set structure (soup, main, side, salad, dessert) and name at least one specific Vietnamese dish besides rice, in English. Every dish named must be on the profile menu and in English: Wednesday's pan-fried salmon IS on the European menu, so naming it is correct; "cá hồi áp chảo" fails rule 4, not rule 2. European first; no day named; adds new facts, does not repeat the first answer's dishes. |
| 63 | What's the difference between fish and shellfish? → (short answer as in 57) | (within 5 s) What's your name? | My name is Minh Le. | A new, different question gets the short answer, not a detailed one. |

## I. Australian food safety and WHS (answers must match the source)
Short B1 answers in the first person ("I"), complete on every point asked. A Code requirement must not be swapped for a guidance figure, or the other way round.
| # | Question | Ideal answer | Must / must not | Source |
|---|---|---|---|---|
| 64 | What temperature must potentially hazardous food be when you receive it? | Cold food must be 5 °C or below. Hot food must be 60 °C or above. Frozen food must arrive frozen. | Both limits + frozen. | FSANZ 3.2.2 cl 5(3)–(4) |
| 65 | How fast must you cool cooked food? | From 60 to 21 °C within two hours. Then down to 5 °C within a further four hours. | Both stages. | 3.2.2 cl 7(3) |
| 66 | What temperature do you reheat food to for hot holding? | I reheat it quickly to at least 60 °C. I aim for 75 °C in the centre. I never reheat in a bain-marie. | 60 °C is the Code limit; 75 °C only as a recommendation. | 3.2.2 cl 7(4); FSANZ guidance |
| 67 | What does sanitise mean? | Sanitising means using heat or chemicals on a clean surface. It reduces germs to a safe level. | Must NOT say it kills all germs. | 3.2.2 cl 20(2) |
| 68 | How can you sanitise utensils? | I use hot water at 77 °C for 30 seconds. Or I use a chemical sanitiser as the label says. Or I use a dishwasher's sanitising cycle. | Heat, chemical, or both. | FSANZ cleaning and sanitising; Safe Food Australia App. 6 |
| 69 | What must you do if you have diarrhoea? | I tell my supervisor and I don't handle food. I stay away from food until 48 hours after the symptoms stop. | Report + no food handling; 48 h as health advice. | 3.2.2 cl 14; state health guidance |
| 70 | When must you wash your hands? | I wash them before I handle food and after the toilet. I wash them after raw food, before ready-to-eat food. I also wash them after coughing, sneezing, eating or touching my hair. | At least 3 of these times. | 3.2.2 cl 15(2)–(3) |
| 71 | What does a food safety supervisor need? | A food safety supervisor certificate from the last five years. They also need the authority to direct staff, and to be reasonably available. | 5 years. | 3.2.2A cl 2, 11 |
| 72 | How long do you keep food safety records? | We're a category one business, so we keep them for at least three months. | 3 months. | 3.2.2A cl 12(2) |
| 73 | Which allergens must be declared in Australia? | Milk, egg, peanut, tree nuts, sesame, soy and fish. Also crustacea, molluscs, wheat, lupin, gluten cereals and sulphites. | Lupin and sesame included; no "mustard" or "celery" (EU list). | FSANZ PEAL, Std 1.2.3 and Schedule 9 |
| 74 | What is the hierarchy of control? | Eliminate the hazard, substitute it, isolate it, then use engineering controls. Then administrative controls, and PPE last. | Correct order. | Model WHS Regulations r 36 |
| 75 | What is an SDS? | A Safety Data Sheet. It tells me a chemical's hazards, safe use, storage, PPE and first aid. | — | Model WHS Regulations; Safe Work Australia |
| 76 | How do you lift a heavy box of stock safely? | I check the weight first. If it's heavy, I use a trolley or get help. I bend my knees and keep the box close to my body. | Assess first, aids or help. | Safe Work Australia Code of Practice: Hazardous manual tasks |

## J. SA Cook questionnaire topics (answers must match the KB)
Short B1 answers in the first person ("I"), complete on every point asked. The KB fact column names the knowledge file and the note the answer must agree with.
| # | Question | Ideal answer | Must / must not | KB fact |
|---|---|---|---|---|
| 77 | I had gastro but I feel better this morning. What do you do? | I phone my supervisor before my shift and stay home. I come back only 48 hours after the symptoms stop. | Phone, not text; 48 h. Must NOT say feeling better is enough. | 01 Sick procedure (SITXFSA005) |
| 78 | How do you check that a probe thermometer is accurate? | I put the probe in crushed ice with a little water. I wait about 3 minutes. It must read 0 °C, within 1 °C. | Ice point 0 °C, ±1 °C; about 3 minutes (FSANZ). | 01 Thermometer ice-point check; 3.2.2 cl 22 |
| 79 | Your thermometer reads 6 °C in ice water. What do you do? | It's 6 degrees out, so I stop using it. I tag it and use a backup. I tell my supervisor and recheck food it measured. | Outside ±1 °C → stop using it. Must NOT call 6 °C fine because it is near 5 °C. | 01 Ice-point check, 6 °C case |
| 80 | How do you store food in the cool room, from top to bottom? | I put cooked and ready-to-eat food on top, then vegetables. Then I put raw seafood, raw meat and mince. Raw chicken goes at the bottom. | Ready-to-eat on top, raw poultry at the bottom; raw never above ready-to-eat. | 01 Cool room order |
| 81 | Two cooks are arguing during service. What do you do? | I calmly ask them to stop and step away from the line. I call the supervisor, and we sort it out after service. | Safety, supervisor, private talk after service; must not take sides. | 14 Two cooks arguing (SITHCCC043) |
| 82 | What do you write in a handover note? | I write the prep done and still to do. I note food cooling with its start time and low stock. I add equipment faults and allergen notes. | At least 3 items from the KB list. | 14 Handover notes |
| 83 | What do you go through in a shift briefing? | We go through covers and bookings, specials and menu changes, and 86'd items. We also go through allergies and dietary requests, and our sections. | Allergies + at least 2 more items. | 14 Shift briefing |
| 84 | What's the difference between cross-contamination and cross-contact? | Cross-contamination moves bacteria onto food; cross-contact moves an allergen into allergen-free food. Cooking doesn't remove allergens. | Allergen = cross-contact; cooking does not remove allergens. | 13 Cross-contamination vs cross-contact |
| 85 | A customer has an allergic reaction to a dish. What do you do? | I call 000 and give first aid. I tell the manager, keep the dish and packaging, and write an incident report. | 000 and first aid first; keep the dish. | 13 Allergen incident |
| 86 | A chicken pasta costs $4.50 a portion and the target food cost is 30%. What's the menu price? | $4.50 divided by 0.30 is $15 without GST. So the menu price is $16.50 with GST. | $15.00 ex-GST, $16.50 with GST; must NOT use $4.50 × 1.3. | 16 Costing a chicken pasta dish |
| 87 | The price of seafood goes up a lot. What do you do? | I re-cost the recipe first. Then I can raise the price a little or trim the portion. Or I use a cheaper fish or talk to suppliers. | Re-cost first + at least 2 options. | 16 Supplier price rise |
| 88 | How do you handle a customer complaint? | I listen, apologise, solve the problem and thank the customer. If I can't fix it, I get my supervisor. | LAST order (Listen, Apologise, Solve, Thank); escalate. | 20 Complaints (SITXCCS014) |
| 89 | How do you answer the phone at work? | I answer within three rings. I give a greeting, our business name and my name, and I speak clearly. | Three rings; greeting, business name, own name. | 20 Phone (SITXCCS014) |
| 90 | Explain the 2-hour/4-hour rule with an example. | Under 2 hours out of the fridge, I use it or chill it again. 2 to 4 hours, I use it now. Over 4 hours, I bin it. Sandwiches out at 10: chill by 12, use by 2, then bin. | All three bands; times add up; a worked example. | 00 2-hour/4-hour rule (Safe Food Australia App. 2) |
| 91 | How fast must you reheat cooked food to hold it hot? | I reheat it fast to 60°C or above, within 2 hours. I aim for 75°C in the centre. I reheat only once. | ≥60 °C within 2 h (FSANZ); reheat once; must NOT say reheat in the bain-marie. | 00/01 Reheating, 3.2.2 cl 7(4) |
| 92 | How often do you calibrate your thermometer? | The Code sets no fixed time. I follow our food safety program. We check it weekly, and after any drop or odd reading. | Says no fixed legal time; workplace schedule; after a drop or odd reading. | 01 Thermometer check frequency (NSW Food Authority ≥ 6-monthly) |
| 93 | Name six mise en place tasks before dinner service. | I read the prep list, portion meat and fish, and make stocks and sauces. I cut vegetables, set up pans and boards, and label my station. | Six tasks from the KB list. | 14 Mise en place |
| 94 | Give three examples of cross-contamination. | Raw chicken juice drips onto a salad. One board is used for raw meat, then salad. Unwashed hands touch ready-to-eat food. | Three examples; raw → ready-to-eat. | 01 Cross-contamination examples |
| 95 | How do you clean a deep fryer? | I switch it off and let the oil cool fully. I drain the oil and boil it out with fryer cleaner. I rinse and dry it before refilling. | Cool first; dry before refilling (water + hot oil); PPE acceptable extra. | 15 Deep fryer (SITHKOP009) |
| 96 | What is gelatinisation? | Starch heated in liquid, at about 60 to 80°C, takes in water and swells. This thickens the liquid. It happens in pasta, rice and roux sauces. | Starch + heat + liquid; swell/thicken; ~60–80 °C; a farinaceous example. | 07 Gelatinisation (SITHCCC030) |
| 97 | What is mirepoix and what's the ratio? | Mirepoix is rough-cut onion, carrot and celery for flavouring stock. The ratio is half onion, a quarter carrot, a quarter celery. | Onion, carrot, celery; 2:1:1 (50/25/25). | 06 Mirepoix (SITHCCC029) |
| 98 | How is demi-glace made? | I mix equal parts espagnole and brown stock, reduce by half, skim and strain. It is glossy, deep brown and coats a spoon. | Espagnole + brown stock, reduced by half; at least 2 quality signs. | 06 Demi-glace |
| 99 | What's a complete protein? | It has all nine essential amino acids, like soy, quinoa, eggs and dairy. Grains and legumes are incomplete, so I combine them: dhal with rice. | 9 essential amino acids; one complete example; a combination. | 08 Complete vs incomplete proteins (SITHCCC031) |
| 100 | What can replace gelatine in a vegan dessert? | I use agar-agar. It comes from seaweed, sets firmer and must be boiled. Pectin works for fruit jellies. | Agar-agar named; must NOT suggest gelatine-based or animal products. | 08 Gelatine replacers |
| 101 | Which cooking methods suit delicate fish? | For whiting or John Dory I poach, steam or bake in paper. Or I pan-fry gently with a light flour coating. I turn it once. | Gentle methods (≥2 of poach/steam/en papillote/gentle pan-fry); must NOT say hard grilling or boiling. | 10 Delicate fish (SITHCCC037) |
| 102 | A customer asks if a dish has shellfish. What are your obligations? | Fish, crustacea and molluscs are three separate allergens. I check the recipe with the chef, never guess. I tell the customer and mark the docket. | Three separate allergens; check, never guess; docket. | 10 Seafood allergens, Standard 1.2.3 |
| 103 | Name two ways to emulsify a salad dressing. | I whisk oil and vinegar with mustard for a temporary emulsion. Or I whisk oil slowly into egg yolk for a permanent one, like mayonnaise. | Temporary (whisk/shake) and permanent (yolk, slow oil). | 05 Emulsification (SITHCCC028) |
| 104 | How do you truss a chicken and why? | I tuck the wing tips under and cross the legs. I tie them with string around the body. The bird stays compact and cooks evenly. | Method with string; even cooking or shape. | 09 Trussing (SITHCCC035) |
| 105 | How do you check poultry is cooked? | I probe the thickest part of the thigh for 75°C, off the bone. Juices run clear, the leg moves freely, the flesh is firm. | 75°C thigh, clear juices, a texture cue. | 09 Doneness checks (SITHCCC035) |
| 106 | How do you reheat a chicken dish safely? | I reheat it once only, fast, to 75°C in the centre. I serve it or hold it at 60°C or above. Never in a bain-marie. | Once only; rapid; 75°C or ≥60°C; no bain-marie. | 09 Reheating poultry dishes (SITHCCC035) |
| 107 | Define carry-over cooking. | Off the heat, the core keeps rising about 3 to 5 degrees. So I take it off early and rest it. | Core keeps rising; pull early. | 09 Carry-over cooking (SITHCCC036) |
| 108 | A steak is tough and dry. Give three causes. | It was overcooked. It was not rested, or cut with the grain. Or it was a tough cut cooked too fast. | Three distinct causes. | 09 Tough, dry steak (SITHCCC036) |
| 109 | What does the Maillard reaction do when you sear meat? | Above about 140°C the dry surface browns. That gives a crust, colour and deep flavour. It does not seal in the juices. | Browning and flavour; must not claim it seals in juices. | 09 Searing and the Maillard reaction (SITHCCC036) |
| 110 | Give five causes of choux failure and a fix for each. | Collapsed means underbaked, so I bake it until dry. Heavy and not hollow means too much egg, so I add egg slowly. Soggy means it was filled too early, so I fill it near service. Flat means the mix was too soft, so I keep a piping consistency. Cracked means it was piped unevenly, so I pipe evenly. | Five causes, each with a fix (KB: collapsed, heavy, soggy, flat, cracked). | 11 Choux failures and fixes (SITHCCC041) |
| 111 | What is yeast fermentation and how does it affect bread? | Yeast feeds on sugars and makes carbon dioxide and alcohol. The gas lifts the dough and opens the crumb. The alcohol adds flavour. | CO₂ lifts dough; flavour. | 11 Fermentation (SITHCCC041) |
| 112 | What are the quality indicators of a finished dessert? | The texture is true to type and the flavour is balanced. It is served at the right temperature and portion. Plating is neat, with fresh garnish. | Texture, flavour balance, presentation. | 12 Quality indicators (SITHPAT016) |
| 113 | A customer says "I'm allergic to gluten" but orders soy sauce. What do you do? | I explain that regular soy sauce has wheat. I offer gluten-free tamari or leave it out. Then I mark the docket and tell the chef. | Explain wheat; offer tamari or omit; docket and chef. | 13 Soy sauce scenario (SITHCCC042) |
| 114 | Give five sources each of protein, carbohydrates and fats. | Protein: meat, fish, eggs, dairy, legumes. Carbohydrate: bread, rice, pasta, potatoes, oats. Fats: olive oil, butter, avocado, nuts, oily fish. | Five correct items in each group. | 13 Five sources (SITHCCC042) |
| 115 | Why is cleaning and sanitising important in a commercial kitchen? | It removes food and grease where bacteria grow, so it stops food poisoning. It stops cross-contamination, protects allergy customers and meets the Food Standards Code. | Must mention bacteria/food poisoning and the law; must not say "it looks nice" only | 15: why cleaning and sanitising matter — Std 3.2.2 cl 19–20 |
| 116 | What PPE should you wear when cleaning the kitchen? | Rubber gloves, a waterproof apron and enclosed non-slip shoes. Goggles when splashing or decanting, and a mask if the SDS says so. | Must list gloves, eye protection, apron, non-slip shoes | 15: PPE for cleaning |
| 117 | How do you prevent cross-contamination during kitchen cleaning? | I cover or move food first. I clean from cleanest to dirtiest and high to low. I use separate colour-coded cloths for food surfaces, floors and toilets. I sanitise food surfaces at the end. | Must mention separate cloths and order of cleaning | 15: preventing cross-contamination while cleaning |
| 118 | What do you do if you spill cleaning chemicals on the kitchen floor? | I warn others and put up a sign. I put on PPE and check the SDS. I contain it with the spill kit, then wipe and rinse the floor. I ventilate, bin the waste safely and report it. | Must include warn/sign, PPE, SDS, spill kit, report | 15: chemical spill on the floor |
| 119 | How should knives be cleaned safely? | I wash one at a time, blade away from me. I never leave a knife in a sink of water. I wash, rinse, sanitise, dry at once and store it in a rack. | Must say never leave in sink water and one at a time | 15: knives and sharp tools |
| 120 | What are the risks of using the wrong chemical on a food preparation surface? | The chemical can poison or taint the food. It can corrode the surface. Fumes hurt staff. It may not kill bacteria, so food is unsafe. | Must mention chemical contamination of food and ineffective sanitising | 15: wrong chemical on a food surface |
| 121 | A thermometer used for cooked chicken was not sanitised before checking a salad. What problem could occur? | Bacteria move from the chicken to the salad: cross-contamination. The salad is eaten raw, so customers can get food poisoning. | Must say cross-contamination and food poisoning. The fix (sanitise between foods) is not asked, so not required. | 15: unsanitised thermometer |
| 122 | What should you do if you notice signs of pests in the kitchen? | I tell the supervisor at once. I isolate and throw out contaminated food. I clean and sanitise the area, record it and call the licensed pest controller. | Must include report, discard contaminated food, licensed pest controller | 15: pest control — signs and action |
| 123 | During service a staff member stores dirty equipment beside clean dishes. How would you manage it? | I calmly move the dirty items to the dirty side. I re-wash and sanitise any clean items they touched. I remind them of the dirty-to-clean flow and tell the supervisor. | Must include re-sanitising affected clean items and calm communication | 15: dirty equipment beside clean dishes |
| 124 | What is the difference between an à la carte menu and a buffet menu? | À la carte: each dish is priced alone and cooked to order. Buffet: one fixed price, guests serve themselves, so portion control is lost. | Must give both definitions; must mention cooked to order vs self-service | 16: à la carte vs buffet |
| 125 | How do seasonal ingredients influence recipe planning and costing? | In-season produce is cheaper and better quality, so I plan menus around the seasons. Out-of-season items are dear, so I use "market price". | Must link season to price and quality | 16: seasonal ingredients |
| 126 | What is food cost percentage and why is it important? | Portion cost divided by selling price without GST, times 100. It shows how much of each dollar goes on food. So I can set prices and spot waste. | Must give the formula and a reason; ex-GST | 16: food cost % line |
| 127 | How do cultural and ethnic influences affect recipe development? | The customers' backgrounds shape ingredients, flavours and methods, like halal or kosher. I use authentic ingredients, respect religious food rules and describe dishes honestly. | Must mention religious/cultural food rules and authenticity | 16: cultural and ethnic influences |
| 128 | Why is feedback important when planning and improving recipes? | Feedback from customers, floor staff, sales and plate waste shows what to change. I test the change and update the standard recipe. | Must mention a source of feedback and updating the standard recipe | 16: feedback |

## Recording results
For each failed item note: question #, the app's answer, which pass rule failed. Send failures about scope or invented
facts to DATA (knowledge/guide), and failures about format, joining pieces or the "-" reply to BACK END (prompt code).
