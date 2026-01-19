import axios from 'axios';

// Use relative URL - Nginx will proxy to backend
const API_BASE_URL = '/api/notes';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const noteService = {
  getAllNotes: async () => {
    const response = await api.get('');
    return response.data;
  },

  getNoteById: async (id) => {
    const response = await api.get(`/${id}`);
    return response.data;
  },

  createNote: async (title, content, file) => {
    const formData = new FormData();
    formData.append('title', title);
    formData.append('content', content);
    if (file) {
      formData.append('file', file);
    }

    const response = await api.post('', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },

  updateNote: async (id, title, content, file) => {
    const formData = new FormData();
    formData.append('title', title);
    formData.append('content', content);
    if (file) {
      formData.append('file', file);
    }

    const response = await api.put(`/${id}`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },

  deleteNote: async (id) => {
    const response = await api.delete(`/${id}`);
    return response.data;
  },

  downloadFile: (id) => {
    return `${API_BASE_URL}/${id}/file`;
  },
};

export default noteService;
