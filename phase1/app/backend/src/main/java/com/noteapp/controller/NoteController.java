package com.noteapp.controller;

import com.noteapp.dto.NoteDTO;
import com.noteapp.service.NoteService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/notes")
@CrossOrigin(origins = "http://localhost:3000")
public class NoteController {
    
    @Autowired
    private NoteService noteService;
    
    @GetMapping
    public ResponseEntity<List<NoteDTO>> getAllNotes() {
        List<NoteDTO> notes = noteService.getAllNotes();
        return ResponseEntity.ok(notes);
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<NoteDTO> getNoteById(@PathVariable Long id) {
        try {
            NoteDTO note = noteService.getNoteById(id);
            return ResponseEntity.ok(note);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }
    
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> createNote(
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam(value = "file", required = false) MultipartFile file) {
        try {
            NoteDTO createdNote = noteService.createNote(title, content, file);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdNote);
        } catch (IOException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error creating note: " + e.getMessage());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
    
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> updateNote(
            @PathVariable Long id,
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam(value = "file", required = false) MultipartFile file) {
        try {
            NoteDTO updatedNote = noteService.updateNote(id, title, content, file);
            return ResponseEntity.ok(updatedNote);
        } catch (IOException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error updating note: " + e.getMessage());
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNote(@PathVariable Long id) {
        try {
            noteService.deleteNote(id);
            return ResponseEntity.ok().body("Note deleted successfully");
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }
    
    @GetMapping("/{id}/file")
    public ResponseEntity<?> downloadFile(@PathVariable Long id) {
        try {
            byte[] fileData = noteService.getFileData(id);
            String fileName = noteService.getFileName(id);
            String fileType = noteService.getFileType(id);
            
            ByteArrayResource resource = new ByteArrayResource(fileData);
            
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(fileType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, 
                            "attachment; filename=\"" + fileName + "\"")
                    .body(resource);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }
}
