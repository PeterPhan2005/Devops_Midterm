import React, { useState, useEffect } from 'react';
import './App.css';
import { FaPlus, FaTrash, FaTimes, FaPaperclip, FaDownload } from 'react-icons/fa';
import noteService from './services/noteService';

function App() {
  const [notes, setNotes] = useState([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentNote, setCurrentNote] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    content: '',
    file: null,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchNotes();
  }, []);

  const fetchNotes = async () => {
    try {
      setLoading(true);
      const data = await noteService.getAllNotes();
      setNotes(data);
    } catch (error) {
      console.error('Error fetching notes:', error);
      alert('Error loading notes. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const openModal = (note = null) => {
    if (note) {
      setCurrentNote(note);
      setFormData({
        title: note.title,
        content: note.content,
        file: null,
      });
    } else {
      setCurrentNote(null);
      setFormData({
        title: '',
        content: '',
        file: null,
      });
    }
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setCurrentNote(null);
    setFormData({
      title: '',
      content: '',
      file: null,
    });
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file && file.size > 5 * 1024 * 1024) {
      alert('File size exceeds 5MB limit!');
      e.target.value = '';
      return;
    }
    setFormData((prev) => ({
      ...prev,
      file: file,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!formData.title.trim()) {
      alert('Please enter a title!');
      return;
    }

    try {
      if (currentNote) {
        // Update existing note
        await noteService.updateNote(
          currentNote.id,
          formData.title,
          formData.content,
          formData.file
        );
      } else {
        // Create new note
        await noteService.createNote(
          formData.title,
          formData.content,
          formData.file
        );
      }
      
      await fetchNotes();
      closeModal();
    } catch (error) {
      console.error('Error saving note:', error);
      alert('Error saving note. Please try again.');
    }
  };

  const handleDelete = async (id, e) => {
    e.stopPropagation();
    
    if (window.confirm('Are you sure you want to delete this note?')) {
      try {
        await noteService.deleteNote(id);
        await fetchNotes();
      } catch (error) {
        console.error('Error deleting note:', error);
        alert('Error deleting note. Please try again.');
      }
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  return (
    <div className="app">
      <header className="header">
        <h1>📝 My Notes</h1>
        <p>Organize your thoughts beautifully</p>
      </header>

      {loading ? (
        <div className="loading">Loading your notes...</div>
      ) : notes.length === 0 ? (
        <div className="empty-state">
          <div className="empty-state-icon">📋</div>
          <h2>No notes yet</h2>
          <p>Click the + button to create your first note!</p>
        </div>
      ) : (
        <div className="notes-container">
          {notes.map((note) => (
            <div
              key={note.id}
              className="note-card"
              onClick={() => openModal(note)}
            >
              <div className="note-header">
                <h3 className="note-title">{note.title}</h3>
                <button
                  className="delete-btn"
                  onClick={(e) => handleDelete(note.id, e)}
                  title="Delete note"
                >
                  <FaTrash />
                </button>
              </div>
              <p className="note-content">{note.content}</p>
              <div className="note-footer">
                <span className="note-date">{formatDate(note.updatedAt)}</span>
                {note.hasFile && (
                  <span className="file-indicator">
                    <FaPaperclip /> {note.fileName}
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      <button
        className="add-note-btn"
        onClick={() => openModal()}
        title="Add new note"
      >
        <FaPlus />
      </button>

      {isModalOpen && (
        <div className="modal-overlay" onClick={closeModal}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">
                {currentNote ? 'Edit Note' : 'New Note'}
              </h2>
              <button className="close-btn" onClick={closeModal}>
                <FaTimes />
              </button>
            </div>

            <form onSubmit={handleSubmit}>
              <div className="form-group">
                <label htmlFor="title">Title *</label>
                <input
                  type="text"
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleInputChange}
                  placeholder="Enter note title..."
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="content">Content</label>
                <textarea
                  id="content"
                  name="content"
                  value={formData.content}
                  onChange={handleInputChange}
                  placeholder="Write your note here..."
                />
              </div>

              <div className="form-group">
                <label htmlFor="file">
                  <FaPaperclip /> Attach File (Max 5MB)
                </label>
                <input
                  type="file"
                  id="file"
                  className="file-input"
                  onChange={handleFileChange}
                />
                {formData.file && (
                  <div className="file-info">
                    Selected: {formData.file.name} (
                    {(formData.file.size / 1024).toFixed(2)} KB)
                  </div>
                )}
                {currentNote && currentNote.hasFile && !formData.file && (
                  <div className="file-preview">
                    <div className="file-info">Current file: {currentNote.fileName}</div>
                    {currentNote.fileType && currentNote.fileType.startsWith('image/') ? (
                      <img 
                        src={currentNote.attachmentUrl} 
                        alt={currentNote.fileName}
                        className="preview-image"
                      />
                    ) : (
                      <a 
                        href={currentNote.attachmentUrl} 
                        download={currentNote.fileName}
                        className="download-link"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <FaDownload /> Download {currentNote.fileName}
                      </a>
                    )}
                  </div>
                )}
              </div>

              <div className="modal-actions">
                <button type="button" className="btn btn-secondary" onClick={closeModal}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  {currentNote ? 'Update' : 'Create'} Note
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
