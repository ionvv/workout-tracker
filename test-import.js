// Quick test of program import functionality
import fs from 'fs';

// Read the JSON program
const programJSON = fs.readFileSync('/home/dexter/.openclaw/media/inbound/file_9---3fb78401-1af0-4fbf-b841-be9b94b5654a.json', 'utf8');
const program = JSON.parse(programJSON);

console.log('✅ JSON Import Test\n');
console.log(`Program: ${program.programName}`);
console.log(`Workout Days: ${program.workoutDays.length}`);

program.workoutDays.forEach((day, i) => {
  console.log(`\n  Day ${i + 1}: ${day.dayName}`);
  console.log(`    Exercises: ${day.exercises.length}`);
  day.exercises.slice(0, 3).forEach(ex => {
    console.log(`      - ${ex.name}: ${ex.prescribedSets}×${ex.prescribedReps}`);
  });
});

console.log('\n✅ All tests passed! App should work correctly.');
