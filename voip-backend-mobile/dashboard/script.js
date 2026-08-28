const API_BASE = '/api';

// DOM Elements
const usersTableBody = document.getElementById('usersTableBody');
const btnNewUser = document.getElementById('btnNewUser');
const userModal = document.getElementById('userModal');
const closeBtns = document.querySelectorAll('.close-btn');
const newUserForm = document.getElementById('newUserForm');
const searchInput = document.getElementById('searchInput');

// State
let users = [];

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    fetchUsers();
});

// Fetch Users from API
async function fetchUsers() {
    try {
        const response = await fetch(`${API_BASE}/users`);
        const result = await response.json();
        
        if (result.success) {
            users = result.data;
            renderUsers();
        } else {
            console.error('Failed to fetch users:', result.message);
        }
    } catch (error) {
        console.error('Error fetching users:', error);
    }
}

// Render Users Table
function renderUsers() {
    usersTableBody.innerHTML = '';
    
    if (users.length === 0) {
        usersTableBody.innerHTML = '<tr><td colspan="5" style="text-align: center;">No users found.</td></tr>';
        return;
    }

    const searchTerm = searchInput.value.toLowerCase();
    
    users.filter(u => 
        u.username.toLowerCase().includes(searchTerm) || 
        u.sip_username.toLowerCase().includes(searchTerm)
    ).forEach(user => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>#${user.id}</td>
            <td><strong>${user.username}</strong></td>
            <td>${user.sip_username}</td>
            <td><span style="background: rgba(59, 130, 246, 0.2); color: var(--primary); padding: 4px 8px; border-radius: 4px; font-size: 0.8rem;">from-internal</span></td>
            <td>
                <button class="btn btn-danger" onclick="deleteUser(${user.id}, '${user.username}')">
                    <i class="fa-solid fa-trash"></i> Delete
                </button>
            </td>
        `;
        usersTableBody.appendChild(tr);
    });
}

// Search Filter
searchInput.addEventListener('input', renderUsers);

// Modal Logic
btnNewUser.addEventListener('click', () => {
    userModal.classList.add('show');
});

closeBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        userModal.classList.remove('show');
        newUserForm.reset();
    });
});

// Create New User
newUserForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const username = document.getElementById('username').value;
    const phoneNumber = document.getElementById('phoneNumber').value;
    const password = document.getElementById('password').value;
    
    const btnSubmit = document.getElementById('btnSubmit');
    const originalText = btnSubmit.innerText;
    btnSubmit.innerText = 'Creating...';
    btnSubmit.disabled = true;

    try {
        const response = await fetch(`${API_BASE}/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                username: username,
                phone_number: phoneNumber,
                password: password
            })
        });
        
        const result = await response.json();
        if (result.success) {
            alert('User created successfully!');
            userModal.classList.remove('show');
            newUserForm.reset();
            fetchUsers(); // Refresh table
        } else {
            alert('Error: ' + result.message);
        }
    } catch (error) {
        alert('Failed to connect to server.');
    } finally {
        btnSubmit.innerText = originalText;
        btnSubmit.disabled = false;
    }
});

// Delete User
async function deleteUser(id, username) {
    if (!confirm(`Are you sure you want to delete user ${username}? This action will permanently remove their extension from the PBX.`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/users/${id}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        if (result.success) {
            fetchUsers();
        } else {
            alert('Error deleting user: ' + result.message);
        }
    } catch (error) {
        alert('Failed to delete user.');
    }
}
