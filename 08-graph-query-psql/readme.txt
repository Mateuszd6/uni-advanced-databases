Algorytm użyty do przeszukiwania grafu polega na przeszukiwaniu w jednej
iteracji wszystkich sąsiadów wszystkich wierzchołków. Każdy wierzchołek posiada
numer spónej składowej do niego przypisany (na początku cc(v) = v). Następnie w
każdej iteracji algorytmu dla każdego wierzchołka patrzymy na jego sąsiadów.
Jeśli dla sąsiada w; cc(w) < cc(v), to znaczy że musimy zaktualizować numer
spónej składowej. Wtedy wszystkim wierzchołkom i, które mają cc(i) = cc(v),
przypisujemy cc(i) = cc(w). W ten sposób potrzebujemy mało iteracji żeby
połączyć wszystkie składowe grafu. Takie podejście daje znacznie lepsze efekty
od pisania zwykłego BFS'a w plsql'u, ponieważ jest to po prostu pojedyńczy sql
(długi, ale jeden), wykonywany w prostej pętli w plsqlu. To zapytanie robi
update na rekordach z tablicy cc i zwraca ile rekordów zmieniono, robimy je
dopóki nic się nie zmieni, wtedy wiemy że skończyliśmy. Mała liczba kroków tego
algorytmu sugeruje że ten graf jest dość gęsty.

Czasy zapytań od poniżej minuty do paru minut - prawdopodobnie rozgrzał się w
międzyczasie cache, więc te ostatnie mogły by być nieco większe.

Testy zostały przeprowadzone dla wszystkich krawędzi i dla krawędzi, gdzie
liczba publikacji jest większa lub równa 2 (70 percentyl), 2 (86 percentyl) i 13
2 (99 percentyl).

Tendencja jest wszędzie taka sama; jedna (bardzo) duża składowa i wiele
małych. Zwiększenie wymaganej wagi krawędzi obniża wielkość głównej składowej,
ale tendencja jest ciągle ta sama.
