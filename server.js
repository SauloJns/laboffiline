const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

let tasks = [
  {
    id: 'server_1',  
    title: 'Tarefa Inicial do Servidor',
    description: 'Criada automaticamente pelo servidor',
    completed: false,
    priority: 'medium',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }
];

app.get('/api/tasks', (req, res) => {
  console.log('📥 GET /api/tasks - Retornando', tasks.length, 'tasks');
  res.json(tasks);
});

app.post('/api/tasks', (req, res) => {
  const newTask = {
    id: 'server_' + Date.now().toString(), 
    ...req.body,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };
  
  tasks.push(newTask);
  console.log('🆕 POST /api/tasks - Task criada:', newTask.title);
  res.status(201).json(newTask);
});

app.put('/api/tasks/:id', (req, res) => {
  const taskId = req.params.id;
  const updatedData = req.body;
  
  const taskIndex = tasks.findIndex(task => task.id === taskId);
  
  if (taskIndex === -1) {
    return res.status(404).json({ error: 'Task não encontrada' });
  }
  
  tasks[taskIndex] = {
    ...tasks[taskIndex],
    ...updatedData,
    updated_at: new Date().toISOString() 
  };
  
  console.log('✏️ PUT /api/tasks/' + taskId + ' - Task atualizada:', tasks[taskIndex].title);
  console.log('🕒 NOVO TIMESTAMP:', tasks[taskIndex].updated_at);
  res.json(tasks[taskIndex]);
});

app.delete('/api/tasks/:id', (req, res) => {
  const taskId = req.params.id;
  const initialLength = tasks.length;
  tasks = tasks.filter(task => task.id !== taskId);
  
  console.log('🗑️ DELETE /api/tasks/' + taskId + ' - Tasks: ' + initialLength + ' → ' + tasks.length);
  res.status(204).send();
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(3000, () => {
  console.log(' SERVIDOR: http://localhost:3000');
  console.log(' Endpoints SAULO JOSÉ:');
  console.log('   GET    http://localhost:3000/api/tasks');
  console.log('   POST   http://localhost:3000/api/tasks');
  console.log('   PUT    http://localhost:3000/api/tasks/:id');
  console.log('   DELETE http://localhost:3000/api/tasks/:id');
  console.log('   HEALTH http://localhost:3000/api/health');
});