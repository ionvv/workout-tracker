#!/usr/bin/env node

import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const BASE_URL = 'https://wger.de';
const API_URL = `${BASE_URL}/api/v2/exerciseinfo/`;
const LANGUAGE = 2; // English
const OUTPUT_FILE = path.join(__dirname, '../public/exercises-database.json');

// Muscle group mapping
const muscleMap = {
  'Shoulders': 'shoulders',
  'Anterior deltoid': 'shoulders',
  'Chest': 'chest',
  'Pectoralis major': 'chest',
  'Lats': 'lats',
  'Latissimus dorsi': 'lats',
  'Biceps': 'biceps',
  'Biceps brachii': 'biceps',
  'Triceps': 'triceps',
  'Triceps brachii': 'triceps',
  'Quads': 'quadriceps',
  'Quadriceps femoris': 'quadriceps',
  'Hamstrings': 'hamstrings',
  'Biceps femoris': 'hamstrings',
  'Glutes': 'glutes',
  'Gluteus maximus': 'glutes',
  'Calves': 'calves',
  'Gastrocnemius': 'calves',
  'Soleus': 'calves',
  'Abs': 'core',
  'Rectus abdominis': 'core',
  'Obliquus externus abdominis': 'core',
  'Lower Back': 'lower-back',
  'Trapezius': 'traps',
  'Back': 'upper-back'
};

// Equipment mapping
const equipmentMap = {
  'none (bodyweight exercise)': 'bodyweight',
  'Barbell': 'barbell',
  'Dumbbells': 'dumbbells',
  'Kettlebell': 'kettlebell',
  'SZ-Bar': 'ez-bar',
  'Gym mat': 'mat',
  'Bench': 'bench',
  'Pull-up bar': 'pull-up-bar',
  'Swiss Ball': 'swiss-ball',
  'Incline bench': 'incline-bench',
  'Cable': 'cable'
};

// Category mapping
const categoryMap = {
  'Arms': 'strength',
  'Legs': 'strength',
  'Abs': 'core',
  'Chest': 'strength',
  'Back': 'strength',
  'Shoulders': 'strength',
  'Calves': 'strength',
  'Cardio': 'cardio'
};

function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function fetchAllExercises() {
  const exercises = [];
  let url = `${API_URL}?language=${LANGUAGE}&limit=100`;
  let page = 1;

  while (url) {
    console.log(`Fetching page ${page}...`);
    const response = await fetchJSON(url);
    
    for (const ex of response.results) {
      // Get English translation
      const translation = ex.translations.find(t => t.language === LANGUAGE);
      if (!translation) continue;

      // Extract muscle groups
      const primaryMuscles = ex.muscles
        .map(m => muscleMap[m.name_en || m.name])
        .filter(Boolean);
      
      const secondaryMuscles = ex.muscles_secondary
        .map(m => muscleMap[m.name_en || m.name])
        .filter(Boolean);

      // Extract equipment
      const equipment = ex.equipment
        .map(e => equipmentMap[e.name] || e.name.toLowerCase())
        .filter(Boolean);

      // Get images
      const images = ex.images.map(img => {
        if (!img.image) return null;
        // Check if URL is already absolute
        const imageUrl = img.image.startsWith('http') ? img.image : `${BASE_URL}${img.image}`;
        return {
          image: imageUrl,
          isMain: img.is_main
        };
      }).filter(img => img);

      // Get main image (prefer GIF or first image)
      let gifUrl = null;
      if (images.length > 0) {
        const mainImg = images.find(img => img.isMain) || images[0];
        gifUrl = mainImg.image;
      }

      // Determine difficulty (basic heuristic)
      let difficulty = 'intermediate';
      if (equipment.includes('bodyweight') && primaryMuscles.length <= 2) {
        difficulty = 'beginner';
      } else if (equipment.includes('barbell') && primaryMuscles.length >= 3) {
        difficulty = 'advanced';
      }

      // Clean description (remove HTML)
      const description = translation.description
        .replace(/<[^>]*>/g, '')
        .replace(/\n/g, ' ')
        .trim()
        .substring(0, 200);

      const exercise = {
        id: `ex${String(ex.id).padStart(3, '0')}`,
        name: translation.name,
        slug: translation.name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
        description: description || `${ex.category.name} exercise`,
        muscleGroups: {
          primary: [...new Set(primaryMuscles)],
          secondary: [...new Set(secondaryMuscles)]
        },
        equipment: [...new Set(equipment)],
        difficulty: difficulty,
        category: categoryMap[ex.category.name] || 'strength',
        media: {
          gifUrl: gifUrl
        }
      };

      // Skip if no muscle groups or name
      if (exercise.muscleGroups.primary.length === 0 || !exercise.name) {
        continue;
      }

      exercises.push(exercise);
    }

    url = response.next;
    page++;
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return exercises;
}

async function main() {
  console.log('Fetching exercises from Wger API...');
  
  try {
    const exercises = await fetchAllExercises();
    
    const database = {
      version: '2.0',
      source: 'wger.de',
      license: 'CC-BY-SA 4.0',
      lastUpdated: new Date().toISOString().split('T')[0],
      count: exercises.length,
      exercises: exercises
    };

    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(database, null, 2));
    
    console.log(`✅ Saved ${exercises.length} exercises to exercises-database.json`);
    console.log(`   - With images: ${exercises.filter(e => e.media.gifUrl).length}`);
    console.log(`   - Without images: ${exercises.filter(e => !e.media.gifUrl).length}`);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();
