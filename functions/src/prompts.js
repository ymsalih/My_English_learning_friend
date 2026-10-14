// Yapay zekaya giden talimatlar. Uygulamadan sunucuya taşındı: istemci
// yalnızca seçenekleri (mod, seviye, tür) ve kullanıcının mesajını gönderir,
// böylece anahtar ele geçirilse bile model başka işler için kullanılamaz.

const stringSchema = (description) => ({ type: 'STRING', ...(description ? { description } : {}) });
const integerSchema = () => ({ type: 'INTEGER' });
const booleanSchema = () => ({ type: 'BOOLEAN' });
const arraySchema = (items) => ({ type: 'ARRAY', items });
/** Tüm alanlar zorunlu; alanlar yazıldığı sırayla üretilir. */
const objectSchema = (properties) => ({
  type: 'OBJECT',
  properties,
  required: Object.keys(properties),
  propertyOrdering: Object.keys(properties),
});

/** Uygunsuz içerik orta ve üzeri olasılıkta engellenir. */
export const SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
];

// --- Sohbet ---

// "reply" önce gelir: kullanıcı cevabı akarken okumaya başlar, düzeltme en
// sonda tamamlanır.
const CHAT_RESPONSE_SCHEMA = objectSchema({
  reply: stringSchema('Your conversational response in English'),
  correction: objectSchema({
    original: stringSchema(),
    corrected: stringSchema(),
    explanation: stringSchema(),
  }),
});

export function chatSystemPrompt(mode, level) {
  const base = 'You are a friendly AI English tutor. '
    + 'Safety rules: never produce sexual, violent, hateful, harassing, self-harm or illegal content, '
    + 'and never give medical, legal or financial advice. If the user asks for any of that, politely decline '
    + 'in one sentence and steer the conversation back to learning English. '
    + 'If the user seems to be in danger or distress, kindly suggest talking to a trusted adult or local emergency services. '
    + `The user's English level is ${level}. Adapt your vocabulary and grammar accordingly. `
    + 'Keep your reply short and natural like a real chat message: 1-3 sentences, '
    + 'unless the user explicitly asks for a longer answer. Keep the explanation to one short sentence. '
    + 'Always respond in the following JSON format ONLY, do not wrap it in markdown: '
    + '{"reply": "Your conversational response in English", '
    + '"correction": {"original": "The user\'s original sentence with mistakes", '
    + '"corrected": "The grammatically correct version", '
    + '"explanation": "Explanation of the correction in Turkish"}} '
    + "If there are no grammar mistakes in the user's message, set original, corrected, and explanation fields inside correction to empty strings. "
    + 'Ignore punctuation completely: never correct or mention commas, periods, question marks, exclamation marks or other punctuation. '
    + 'If punctuation is the only issue, treat the message as correct (empty correction fields). '
    + "In the corrected sentence keep the user's own punctuation and fix only grammar, vocabulary or spelling.";

  switch (mode) {
    case 'Gramer':
      return `${base} Focus mainly on grammar rules. Ask questions to test their grammar.`;
    case 'Kelime':
      return `${base} Introduce new vocabulary words related to their level. Ask them to use new words.`;
    case 'Günlük':
      return `${base} Have a casual daily conversation (small talk, hobbies, daily life).`;
    case 'İş':
      return `${base} Roleplay as a colleague or business partner. Use professional business English.`;
    case 'Seyahat':
      return `${base} Roleplay travel scenarios (airport, hotel, restaurant).`;
    case 'Serbest':
    default:
      return `${base} Have a free-flowing conversation on any topic the user chooses.`;
  }
}

/** Gemini isteğinin gövdesi. [history]: `{role: 'user'|'model', text}` listesi. */
export function chatRequestBody({ mode, level, history, message }) {
  return {
    contents: [
      ...history.map(({ role, text }) => ({ role, parts: [{ text }] })),
      { role: 'user', parts: [{ text: message }] },
    ],
    systemInstruction: { parts: [{ text: chatSystemPrompt(mode, level) }] },
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: CHAT_RESPONSE_SCHEMA,
      thinkingConfig: { thinkingLevel: 'MINIMAL' },
    },
    safetySettings: SAFETY_SETTINGS,
  };
}

// --- Hikaye ---

// Yapıyı garanti eder: bozuk JSON yüzünden başarısız üretim olmaz.
const STORY_SCHEMA = objectSchema({
  title: stringSchema(),
  nodes: arraySchema(objectSchema({
    id: stringSchema(),
    text: stringSchema(),
    choices: arraySchema(objectSchema({
      text: stringSchema(),
      next_id: stringSchema(),
    })),
    is_ending: booleanSchema(),
  })),
  questions: arraySchema(objectSchema({
    question: stringSchema(),
    options: arraySchema(stringSchema()),
    correctIndex: integerSchema(),
    explanation: stringSchema(),
  })),
});

export function storyPrompt(genre, level) {
  return `
You are a master storyteller for English language learners.
Generate an interactive "Choose your own adventure" story tree in English.
Genre: ${genre}
English Level: ${level}

The story must be suitable for all ages (13+): no sexual content, graphic violence, hate, self-harm, drugs or other harmful material, whatever the genre.

Format the response purely as a JSON object matching this exact schema:
{
  "title": "A catchy title for the story",
  "nodes": [
    {
      "id": "1",
      "text": "Story text for this node. Keep it engaging and appropriate for ${level} level.",
      "choices": [
         {"text": "Choice 1 text in English...", "next_id": "2"},
         {"text": "Choice 2 text in English...", "next_id": "3"}
      ],
      "is_ending": false
    }
  ],
  "questions": [
    {
       "question": "A reading comprehension question about the story?",
       "options": ["A", "B", "C", "D"],
       "correctIndex": 1,
       "explanation": "Brief explanation in English of why this is the correct answer."
    }
  ]
}

Strict Rules:
1. Node "id": "1" is the starting point.
2. The tree MUST be exactly depth 3. So Node 1 leads to Nodes 2 and 3. Node 2 leads to 4 and 5. Node 3 leads to 6 and 7. Nodes 4,5,6,7 are endings.
3. For ending nodes (4,5,6,7), set "is_ending": true and "choices": [].
4. Keep the text simple, clear, and perfectly aligned with the CEFR ${level} level.
5. Create exactly 3 "questions" about the general plot or vocabulary of the story.
`;
}

export function storyRequestBody({ genre, level }) {
  return {
    contents: [{ role: 'user', parts: [{ text: storyPrompt(genre, level) }] }],
    generationConfig: {
      temperature: 0.7,
      responseMimeType: 'application/json',
      responseSchema: STORY_SCHEMA,
      thinkingConfig: { thinkingLevel: 'LOW' },
    },
    safetySettings: SAFETY_SETTINGS,
  };
}
