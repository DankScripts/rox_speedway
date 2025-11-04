window.addEventListener('message', function(event) {
  if (event.data.type === 'lobbyInfo') {
    document.getElementById('lobbyName').textContent = event.data.lobbyName || 'Lobby';
    const memberList = document.getElementById('memberList');
    memberList.innerHTML = '';
    (event.data.members || []).forEach(function(player) {
      const row = document.createElement('tr');
      row.innerHTML = `<td${player.isHost ? ' class="host"' : ''}>${player.name}</td>`;
      memberList.appendChild(row);
    });
    if ((event.data.members || []).length === 0) {
      memberList.innerHTML = '<tr><td class="waiting">Waiting for players...</td></tr>';
    }
    // Show start button only for host
    document.getElementById('startRaceBtn').style.display = event.data.isHost ? 'block' : 'none';
  } else if (event.data.type === 'hideLobby') {
    document.body.style.display = 'none';
  }
});

// Host clicks start race
const startBtn = document.getElementById('startRaceBtn');
if (startBtn) {
  startBtn.addEventListener('click', function() {
    fetch('https://qb_rox_speedway/startRace', { method: 'POST' });
  });
}
